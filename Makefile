EXAMPLES_DIR   = examples
YML_SRCS       = $(wildcard $(EXAMPLES_DIR)/*.yml)
SV_OUTS        = $(patsubst %.yml,%.sv,$(YML_SRCS))
DOT_OUTS       = $(patsubst %.yml,%.dot,$(YML_SRCS))
SCTB_OUTS      = $(patsubst %.yml,%_tb.cc,$(YML_SRCS))
SVTB_OUTS      = $(patsubst %.yml,%_tb.v,$(YML_SRCS))

BIN_OUTS       = $(subst .yml,,$(subst $(EXAMPLES_DIR)/,obj_dir/V,$(YML_SRCS)))
SIMV_OUTS      = $(subst .yml,_simv,$(YML_SRCS))

CALC_SIZE      = $(shell find $(1) -exec du -bc {} + | grep total$ | cut -f1)
YML_SIZE       = $(call CALC_SIZE,$(YML_SRCS))
SV_SIZE        = $(call CALC_SIZE,$(SV_OUTS))

ROOT_DIR       = $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
FSM2SV         = $(ROOT_DIR)/fsm2sv

VERILATOR      = verilator
LINT_ARGS      = -Wall --lint-only
TESTBENCH_ARGS = -Wall --sc --exe --trace -O3 -build --clk clk

IVERILOG       = iverilog
IVERILOG_ARGS  = -g2012 -Wall

PDF_OPTS := --fail-if-warnings \
	-V linkcolor:blue \
	-V citecolor:blue \
	--filter pandoc-secnos \
	--filter pandoc-xnos \
	--citeproc \
	-V fontsize=11pt \
	-V fontfamily=times \
	-V geometry:a4paper \
	-V geometry:margin=2cm \
	--pdf-engine=pdflatex

.PHONY: clean all flake pylint sizes test-sv test-sc docs

all: $(SV_OUTS) $(DOT_OUTS) $(SVTB_OUTS) $(SCTB_OUTS)

test-sv: $(SIMV_OUTS)

test-sc: $(BIN_OUTS)

obj_dir/V%: $(EXAMPLES_DIR)/%_tb.cc $(EXAMPLES_DIR)/%.sv
	$(VERILATOR) $(TESTBENCH_ARGS) $^
	cd obj_dir && ./V$*

%_simv: %.sv %_tb.v
	$(IVERILOG) $(IVERILOG_ARGS) -o $@ $^
	cd $(EXAMPLES_DIR) && ../$*_simv

# Generate the SV FSM and validate it with verilator linter
# To use another linter, just change $(LINT) and $(LINT_ARGS) above
%.sv : %.yml
	$(FSM2SV) -i $< -o $@
	$(VERILATOR) $(LINT_ARGS) $@

# dot will print the file with layout attributes to stdout
%.dot : %.yml
	$(FSM2SV) -i $< -d $@
	dot -Tdot $@ > /dev/null

%_tb.cc : %.yml
	$(FSM2SV) -i $< -t sc $@

%_tb.v : %.yml
	$(FSM2SV) -i $< -t sv $@

flake: $(FSM2SV)
	flake8 $<

pylint: $(FSM2SV)
	pylint $<

docs: README.md
	pandoc $(PDF_OPTS) -t latex $< -o docs/fsm2sv.pdf

sizes:
	@echo "YML files total size = $(YML_SIZE)"
	@echo "SV files total size = $(SV_SIZE)"
	@echo -n "SV to YML size ratio = "
	@echo "scale=4; $(SV_SIZE) / $(YML_SIZE)" | bc

clean:
	$(RM) $(SV_OUTS)
	$(RM) $(DOT_OUTS)
	$(RM) $(SCTB_OUTS)
	$(RM) $(SVTB_OUTS)
	$(RM) $(SIMV_OUTS)
	$(RM) -r obj_dir
