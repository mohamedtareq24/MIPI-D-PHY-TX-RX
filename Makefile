VIVADO ?= vivado
PROJECT ?= D-PHY
TOP ?= clock_lane
BUILD_DIR ?= $(CURDIR)/build/vivado_dphy
SRC_DIR ?= $(CURDIR)/src
JOBS ?= 64

SYNTH_TCL := scripts/vivado_synth.tcl
OPEN_TCL := scripts/open_project.tcl

.PHONY: help syn open open_top clean

help:
	@echo "Targets:"
	@echo "  make syn TOP=<top_module>          # Reuse existing project and run synthesis"
	@echo "  make open                          # Open project in Vivado GUI"
	@echo "  make open_top TOP=<top_module>     # Open GUI and set top"
	@echo "  make clean                         # Remove generated build directory"
	@echo ""
	@echo "Variables (override as needed):"
	@echo "  VIVADO=$(VIVADO)"
	@echo "  PROJECT=$(PROJECT)"
	@echo "  TOP=$(TOP)"
	@echo "  BUILD_DIR=$(BUILD_DIR)"
	@echo "  SRC_DIR=$(SRC_DIR)"
	@echo "  JOBS=$(JOBS)"

syn:
	$(VIVADO) -mode batch -source $(SYNTH_TCL) -tclargs \
		-top $(TOP) \
		-project $(PROJECT) \
		-build_dir $(BUILD_DIR) \
		-src_dir $(SRC_DIR) \
		-jobs $(JOBS)

open:
	$(VIVADO) -mode gui -source $(OPEN_TCL) -tclargs \
		-project $(PROJECT) \
		-build_dir $(BUILD_DIR)

open_top:
	$(VIVADO) -mode gui -source $(OPEN_TCL) -tclargs \
		-project $(PROJECT) \
		-build_dir $(BUILD_DIR) \
		-top $(TOP)

clean:
	rm -rf *.log *.jou *.str