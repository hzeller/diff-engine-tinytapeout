TOP=main
DELAY_MODEL=sky130
PIPELINE_STAGES=1

# Could be overriden by environment variable, e.g. to point to local bazel build
XLS_IR_CONVERTER ?= xls-ir-converter
XLS_INTERPRETER  ?= xls-interpreter
XLS_OPT          ?= xls-opt
XLS_CODEGEN      ?= xls-codegen

# Tiny Tapeout reads Verilog sources from src/ (see info.yaml). The whole
# directory is a build product: git only tracks main.x, wrapper.sv and
# config.json.
all: src/diff_engine.sv src/spi.sv src/project.sv src/config.json

# Rebuild generated files when the XLS toolchain itself changes: the stamp
# holds the toolchain's store path and only gets rewritten when it differs
# (nix store mtimes are all epoch, so the path can't be a prerequisite).
XLS_STAMP=.xls-toolchain
$(XLS_STAMP): FORCE
	@echo "$(DSLX_STDLIB_PATH)" | cmp -s - $@ || echo "$(DSLX_STDLIB_PATH)" > $@
FORCE:

%.ir: %.x $(XLS_STAMP)
	$(XLS_IR_CONVERTER) --top=$(TOP) --dslx_stdlib_path=$(DSLX_STDLIB_PATH) --output_file=$@ $<

%.opt.ir: %.ir
	$(XLS_OPT) --output_path=$@ $^

src/%.sv: %.opt.ir
	mkdir -p src
	$(XLS_CODEGEN) --delay_model=$(DELAY_MODEL) --pipeline_stages=$(PIPELINE_STAGES) \
	  --module_name=xls_$* --reset=rst_n --reset_active_low \
	  --output_verilog_path=$@ --use_system_verilog $^

src/project.sv: wrapper.sv
	mkdir -p src
	cp $< $@

src/config.json: config.json
	mkdir -p src
	cp $< $@

%.test: %.x
	$(XLS_INTERPRETER) --dslx_stdlib_path=$(DSLX_STDLIB_PATH) --alsologtostderr $^

test: main.test

# Build (and flash) the current DSLX design for the Arty A7 via the xc7
# flow. Runs the xc7 dev shell for the FPGA leg, so this works from the
# default (XLS) shell. Someday: a `bx` sibling for the TinyFPGA-BX once
# the ice40 leg can emit bitstreams.
arty: all
	nix develop .#xc7 --command $(MAKE) -C fpga/xc7

arty-upload: all
	nix develop .#xc7 --command $(MAKE) -C fpga/xc7 upload

clean:
	rm -rf *.ir src

.PHONY: all test arty arty-upload clean
