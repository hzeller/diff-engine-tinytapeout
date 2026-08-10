# iCE40 LP8K VPR architecture, milestone 1 (approximate routing).
# Dev shell: `nix develop .#ice40` (provides vpr, icestorm, python3 and
# the ICESTORM env var).

CHIPDB?=$(ICESTORM)/share/icebox/chipdb-8k.txt
TIMINGS?=$(ICESTORM)/share/icebox/timings_lp8k.txt

arch.xml: template.xml scripts/chipdb_layout.py scripts/chipdb_timing.py
	python3 scripts/chipdb_layout.py --chipdb $(CHIPDB) --template template.xml --output arch.tmp.xml
	python3 scripts/chipdb_timing.py --timings $(TIMINGS) --input arch.tmp.xml --output $@ --report timing-report.txt
	rm -f arch.tmp.xml

counter.blif: counter.v
	yosys -q -p "read_verilog counter.v; synth -flatten -lut 4; opt_clean; write_blif $@"

# The milestone-1 referee: pack, place and route the counter on the model.
run: arch.xml counter.blif
	vpr arch.xml counter.blif --route_chan_width 100 --clock_modeling route

check: arch.xml
	python3 -c "import xml.etree.ElementTree as ET; ET.parse('arch.xml'); print('arch.xml: well-formed XML')"

clean:
	rm -f arch.xml arch.tmp.xml timing-report.txt counter.blif
	rm -f *.net *.place *.route vpr_stdout.log *.rpt packing_pin_util.rpt pre_pack.report_timing.setup.rpt

.PHONY: run

.PHONY: check clean
