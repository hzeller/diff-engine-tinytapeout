# Verilog -> yosys -> VPR (pack/place/route) -> genfasm -> fpga-as -> .bit
# Tools and data come from the dev shell (flake.nix): vpr, genfasm, yosys,
# python3, and the env vars ARCH_DIR, TECHMAP_PATH, PRJXRAY_DB.

TOP=top
PART=xc7a35tcsg324-1
DEVICE=xc7a50t_test
DEVICE_NAME=xc7a50t-test
FPGA_AS?=$(HOME)/Projects/open-source/fpga-assembler/bazel-bin/fpga/fpga-as

ARCH_XML=$(ARCH_DIR)/arch.timing.xml
RR_GRAPH=$(ARCH_DIR)/rr_graph_$(DEVICE).rr_graph.real.bin
LOOKAHEAD=$(ARCH_DIR)/rr_graph_$(DEVICE).lookahead.bin
PLACE_DELAY=$(ARCH_DIR)/rr_graph_$(DEVICE).place_delay.bin

# The VPR options the f4pga flow uses for xc7 (verbatim).
VPR_OPTIONS=\
  --max_router_iterations 500 \
  --routing_failure_predictor off \
  --router_high_fanout_threshold -1 \
  --constant_net_method route \
  --route_chan_width 500 \
  --router_heap bucket \
  --clock_modeling route \
  --place_delta_delay_matrix_calculation_method dijkstra \
  --place_delay_model delta \
  --router_lookahead extended_map \
  --check_route quick \
  --strict_checks off \
  --allow_dangling_combinational_nodes on \
  --disable_errors check_unbuffered_edges:check_route \
  --congested_routing_iteration_threshold 0.8 \
  --incremental_reroute_delay_ripup off \
  --base_cost_type delay_normalized_length_bounded \
  --bb_factor 10 \
  --acc_fac 0.7 \
  --astar_fac 1.8 \
  --initial_pres_fac 2.828 \
  --pres_fac_mult 1.2 \
  --check_rr_graph off \
  --suppress_warnings noisy_warnings.log,sum_pin_class:check_unbuffered_edges:load_rr_indexed_data_T_values:check_rr_node:trans_per_R:check_route:set_rr_graph_tool_comment:calculate_average_switch

VPR=vpr $(ARCH_XML) $(TOP).eblif --device $(DEVICE_NAME) $(VPR_OPTIONS) \
  --read_rr_graph $(RR_GRAPH) \
  --read_router_lookahead $(LOOKAHEAD) \
  --read_placement_delay_lookup $(PLACE_DELAY)

all: build/$(TOP).bit

# Synthesis: yosys with the vendored f4pga xc7 script (synth.tcl), which
# techmaps to the VPR architecture's cell library and writes the eblif.
build/$(TOP).eblif: counter.v arty.xdc synth.tcl
	mkdir -p build
	cd build && \
	  TOP=$(TOP) \
	  INPUT_XDC_FILES=../arty.xdc \
	  PART_JSON=$(PRJXRAY_DB)/artix7/$(PART)/part.json \
	  TECHMAP_PATH=$(TECHMAP_PATH) \
	  PYTHON3=python3 \
	  UTILS_DIR=$(CURDIR)/scripts \
	  USE_ROI=FALSE \
	  OUT_JSON=$(TOP).json \
	  SYNTH_JSON=$(TOP).synth.json \
	  OUT_SDC=$(TOP).sdc \
	  OUT_SYNTH_V=$(TOP).synth.v \
	  OUT_EBLIF=$(TOP).eblif \
	  OUT_FASM_EXTRA=$(TOP)_fasm_extra.fasm \
	  yosys -p "tcl ../synth.tcl" -l $(TOP).synth.log ../counter.v

build/$(TOP).net: build/$(TOP).eblif
	cd build && $(VPR) --pack

# Note: no XDC pin-LOC constraints are applied (that was f4pga's ioplace
# python layer); VPR auto-places the IOs. The fasm/bitstream is valid, but
# the design's ports won't land on the Arty's LED pins until an ioplace
# step is added.
build/$(TOP).place: build/$(TOP).net
	cd build && $(VPR) --place

build/$(TOP).route: build/$(TOP).place
	cd build && $(VPR) --route

build/$(TOP).fasm: build/$(TOP).route
	cd build && genfasm $(ARCH_XML) $(TOP).eblif --device $(DEVICE_NAME) $(VPR_OPTIONS) --read_rr_graph $(RR_GRAPH)
	cd build && if [ -f $(TOP)_fasm_extra.fasm ]; then cat $(TOP)_fasm_extra.fasm >> $(TOP).fasm; fi

build/$(TOP).bit: build/$(TOP).fasm
	$(FPGA_AS) --prjxray_db_path=$(PRJXRAY_DB)/artix7 --part=$(PART) < $< > $@

clean:
	rm -rf build

.PHONY: all clean
