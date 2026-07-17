TOP=main
DELAY_MODEL=sky130
PIPELINE_STAGES=1

# Tiny Tapeout reads Verilog sources from src/ (see info.yaml). The whole
# directory is a build product: git only tracks main.x, wrapper.sv and
# config.json.
all: src/main.sv src/project.sv src/config.json

%.ir: %.x
	xls-ir-converter --top=$(TOP) --dslx_stdlib_path=$(DSLX_STDLIB_PATH) --output_file=$@ $^

%.opt.ir: %.ir
	xls-opt --output_path=$@ $^

src/main.sv: main.opt.ir
	mkdir -p src
	xls-codegen --delay_model=$(DELAY_MODEL) --pipeline_stages=$(PIPELINE_STAGES) \
	  --module_name=xls_main --reset=rst_n --reset_active_low \
	  --output_verilog_path=$@ --use_system_verilog $^

src/project.sv: wrapper.sv
	mkdir -p src
	cp $< $@

src/config.json: config.json
	mkdir -p src
	cp $< $@

%.test: %.x
	xls-interpreter --dslx_stdlib_path=$(DSLX_STDLIB_PATH) --alsologtostderr $^

test: main.test

clean:
	rm -rf *.ir src

.PHONY: all test clean
