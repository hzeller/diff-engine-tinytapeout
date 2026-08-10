# iCE40 LP8K VPR architecture, milestone 1 (approximate routing).
# Dev shell: `nix develop .#ice40` (provides vpr, icestorm, python3 and
# the ICESTORM env var).

CHIPDB?=$(ICESTORM)/share/icebox/chipdb-8k.txt
TIMINGS?=$(ICESTORM)/share/icebox/timings_lp8k.txt

arch.xml: template.xml scripts/chipdb_layout.py scripts/chipdb_timing.py
	python3 scripts/chipdb_layout.py --chipdb $(CHIPDB) --template template.xml --output arch.tmp.xml
	python3 scripts/chipdb_timing.py --timings $(TIMINGS) --input arch.tmp.xml --output $@ --report timing-report.txt
	rm -f arch.tmp.xml

check: arch.xml
	python3 -c "import xml.etree.ElementTree as ET; ET.parse('arch.xml'); print('arch.xml: well-formed XML')"
	@echo "note: full VPR validation is blocked on the plb/io pb_types (template.xml TODOs)."

clean:
	rm -f arch.xml arch.tmp.xml timing-report.txt

.PHONY: check clean
