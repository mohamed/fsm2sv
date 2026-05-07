EXAMPLES_DIR   = examples
YML_SRCS       = $(wildcard $(EXAMPLES_DIR)/*.yml)
SV_OUTS        = $(patsubst %.yml,%.sv,$(YML_SRCS))
DOT_OUTS       = $(patsubst %.yml,%.dot,$(YML_SRCS))
SVTB_OUTS      = $(patsubst %.yml,%_tb.v,$(YML_SRCS))

SIM_OUTS       = $(subst .yml,,$(subst $(EXAMPLES_DIR)/,obj_dir/V,$(YML_SRCS)))

CALC_SIZE      = $(shell find $(1) -exec du -bc {} + | grep total$ | cut -f1)
YML_SIZE       = $(call CALC_SIZE,$(YML_SRCS))
SV_SIZE        = $(call CALC_SIZE,$(SV_OUTS))

ROOT_DIR       = $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
FSM2SV         = $(ROOT_DIR)/fsm2sv

VERILATOR      = verilator
LINT_ARGS      = -Wall --lint-only
SIM_ARGS       = --assert --timing --binary --trace -O3 -DFORMAL


PDF_OPTS       := --pdf-engine=typst

.PHONY: clean all flake pylint sizes sim docs setup

all: $(SV_OUTS) $(DOT_OUTS) $(SVTB_OUTS)

setup:
	uv sync --extra dev

sim: $(SIM_OUTS) $(SVTB_OUTS)

obj_dir/V%: $(EXAMPLES_DIR)/%.sv $(EXAMPLES_DIR)/%_tb.v
	$(VERILATOR) $(SIM_ARGS) $^
	cd obj_dir && ./V$*

# Generate the SV FSM and validate it with verilator linter
%.sv : %.yml
	uv run $(FSM2SV) -i $< -o $@
	$(VERILATOR) $(LINT_ARGS) $@

# dot will print the file with layout attributes to stdout
%.dot : %.yml
	uv run $(FSM2SV) -i $< -d $@
	dot -Tdot $@ > /dev/null

%_tb.v : %.yml
	uv run $(FSM2SV) -i $< -t $@

flake: $(FSM2SV)
	uv run flake8 $<

pylint: $(FSM2SV)
	uv run pylint $<

docs: README.md
	pandoc $< --from=markdown --to=typst --output - | typst compile - docs/fsm2sv.pdf

sizes:
	@echo "YML files total size = $(YML_SIZE)"
	@echo "SV files total size = $(SV_SIZE)"
	@echo -n "SV to YML size ratio = "
	@echo "scale=4; $(SV_SIZE) / $(YML_SIZE)" | bc

clean:
	$(RM) $(SV_OUTS)
	$(RM) $(DOT_OUTS)
	$(RM) $(SVTB_OUTS)
	$(RM) $(SIM_OUTS)
	$(RM) -r obj_dir
