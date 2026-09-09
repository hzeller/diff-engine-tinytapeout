TOP=Top
DELAY_MODEL=sky130
PIPELINE_STAGES=2
CLOCK_PERIOD_PS=100000  # 10Mhz is 100ns period.

OUTPUT_CHANGING_VARS="$(DSLX_STDLIB_PATH) $(PIPELINE_STAGES) $(CLOCK_PERIOD_PS)"

# Could be overriden by environment variable, e.g. to point to local bazel build
XLS_IR_CONVERTER ?= xls-ir-converter
XLS_INTERPRETER  ?= xls-interpreter
XLS_OPT          ?= xls-opt
XLS_CODEGEN      ?= xls-codegen

YOSYS_OUT_DIR ?= yosys-out

# Tiny Tapeout reads Verilog sources from src/ (see info.yaml). The whole
# directory is a build product: git only tracks main.x, wrapper.sv and
# config.json.
all: src/top.sv src/project.sv src/config.json

# Rebuild generated files when the XLS toolchain itself changes: the stamp
# holds the toolchain's store path and only gets rewritten when it differs
# (nix store mtimes are all epoch, so the path can't be a prerequisite).
XLS_STAMP=.xls-toolchain
$(XLS_STAMP): FORCE
	@echo "$(OUTPUT_CHANGING_VARS)" | cmp -s - $@ || echo "$(OUTPUT_CHANGING_VARS)" > $@
FORCE:

top.ir: top.x spi.x iterative_polynomial_sampler.x

%.ir: %.x $(XLS_STAMP)
	$(XLS_IR_CONVERTER) --top=$(TOP) --dslx_stdlib_path=$(DSLX_STDLIB_PATH) --output_file=$@ $<

%.opt.ir: %.ir
	$(XLS_OPT) --output_path=$@ $^

# We disable system verilog as yosys has some issues with that.
src/%.sv: %.opt.ir
	mkdir -p src
	$(XLS_CODEGEN) --delay_model=$(DELAY_MODEL) \
          --clock_period_ps=$(CLOCK_PERIOD_PS) \
          --pipeline_stages=$(PIPELINE_STAGES) \
          --module_name=xls_$* --reset=rst_n --reset_active_low \
          --materialize_internal_fifos \
          --use_system_verilog=false \
          --output_verilog_path=$@ $^

src/project.sv: wrapper.sv
	mkdir -p src
	cp $< $@

src/config.json: config.json
	mkdir -p src
	cp $< $@

%.test: %.x
	$(XLS_INTERPRETER) --dslx_stdlib_path=$(DSLX_STDLIB_PATH) --alsologtostderr $^

test: top.test spi.test iterative_polynomial_sampler.test

# Build (and flash) the current DSLX design for the Arty A7 via the xc7
# flow. Runs the xc7 dev shell for the FPGA leg, so this works from the
# default (XLS) shell. Someday: a `bx` sibling for the TinyFPGA-BX once
# the ice40 leg can emit bitstreams.
arty: all
	nix develop .#xc7 --command $(MAKE) -C fpga/xc7

arty-upload: all
	nix develop .#xc7 --command $(MAKE) -C fpga/xc7 upload

clean:
	rm -rf *.ir src $(YOSYS_OUT_DIR)


yosys: $(YOSYS_OUT_DIR)/synth.log

$(YOSYS_OUT_DIR):
	mkdir -p $@

$(YOSYS_OUT_DIR)/synth.log: src/project.sv src/top.sv | $(YOSYS_OUT_DIR)
	@if [ -z "$(SKY130_LIB)" ]; then echo "Error: SKY130_LIB environment variable is not set." >&2; exit 1; fi
	yosys -q -l $(YOSYS_OUT_DIR)/synth.log -p "\
	  read_liberty -lib $(SKY130_LIB); \
	  read_verilog -sv src/project.sv src/top.sv; \
	  hierarchy -top tt_um_diff_engine; \
	  proc; flatten; synth -top tt_um_diff_engine; \
	  dfflibmap -liberty $(SKY130_LIB); \
	  abc -liberty $(SKY130_LIB); \
	  clean; \
	  stat -liberty $(SKY130_LIB); \
	  write_verilog -noattr $(YOSYS_OUT_DIR)/synth.v"

synth: yosys

# Keep intermediate results for inspection.
.PRECIOUS: %.ir %.opt.ir

.PHONY: all test yosys synth arty arty-upload clean
