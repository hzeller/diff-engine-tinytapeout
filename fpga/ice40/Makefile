# iCE40 LP8K VPR architecture, milestone 1 (approximate routing).
# Dev shell: `nix develop .#ice40` (provides vpr, icestorm, python3 and
# the ICESTORM env var).

CHIPDB?=$(ICESTORM)/share/icebox/chipdb-8k.txt

arch.xml: template.xml scripts/chipdb_layout.py
	python3 scripts/chipdb_layout.py --chipdb $(CHIPDB) --template template.xml --output $@

check: arch.xml
	python3 -c "import xml.etree.ElementTree as ET; ET.parse('arch.xml'); print('arch.xml: well-formed XML')"
	@echo "note: full VPR validation is blocked on the plb/io pb_types (template.xml TODOs)."

clean:
	rm -f arch.xml

.PHONY: check clean
