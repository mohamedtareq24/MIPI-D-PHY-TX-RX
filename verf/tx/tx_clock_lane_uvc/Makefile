# Xcelium/XRUN Makefile for EB UVM environment

XRUN ?= xrun
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
REPO_ROOT ?= $(abspath $(MAKEFILE_DIR)/../../..)
XILINX_SIM_ASSETS_DIR ?= $(REPO_ROOT)/build/compile_simlib/xcelium
BOOTSTRAP_XILINX_ASSETS ?= $(REPO_ROOT)/scripts/ensure_xilinx_sim_assets.sh
VIVADO_BIN ?= $(shell command -v vivado 2>/dev/null)
VIVADO_HOME ?= $(if $(XILINX_VIVADO),$(XILINX_VIVADO),$(patsubst %/bin/,%,$(dir $(VIVADO_BIN))))
AUTO_VIVADO_GLBL := $(wildcard $(VIVADO_HOME)/data/verilog/src/glbl.v)
GLBL_CANDIDATES := \
	$(XILINX_SIM_ASSETS_DIR)/glbl.v \
	$(AUTO_VIVADO_GLBL) \
	$(HOME)/tools/xilinx23/Vivado/2023.1/data/verilog/src/glbl.v \
	/home/icer/xilinx_sim_libs/glbl.v
SIMLIB_CDSLIB_CANDIDATES := \
	$(XILINX_SIM_ASSETS_DIR)/cds.lib \
	$(HOME)/xilinx_sim_libs/compiled/cds.lib \
	/home/icer/xilinx_sim_libs/compiled/cds.lib
SIMLIB_CDSLIB_FOUND := $(firstword $(wildcard $(SIMLIB_CDSLIB_CANDIDATES)))
DEFAULT_SIMLIB_DIR := $(if $(SIMLIB_CDSLIB_FOUND),$(patsubst %/cds.lib,%,$(SIMLIB_CDSLIB_FOUND)),$(XILINX_SIM_ASSETS_DIR))

TOP      ?= ppi_clk_tb_top
TEST     ?= ppi_clk_test_en
SEED     ?= 1
COVERAGE ?= 0

FILELIST ?= ./tb/run.f

VIVADO_GLBL ?= $(firstword $(wildcard $(GLBL_CANDIDATES)))
VIVADO_SIMLIB_DIR ?= $(DEFAULT_SIMLIB_DIR)
XRUN_DEFINE_OPTS ?=

# Output Directories
RUN_DIR  ?= sim/$(TEST)
TEMP_DIR ?= $(HOME)/temp
COV_DIR  ?= $(TEMP_DIR)
LOG_ELAB ?= $(RUN_DIR)/xrun_elab.log
LOG_RUN  ?= $(RUN_DIR)/xrun.log
LOG_GUI  ?= $(RUN_DIR)/xrun_gui.log

XRUN_OPTS ?= \
    -64bit \
    -sv \
    -uvm \
    -access +rwc \
    +UVM_TESTNAME=$(TEST) \
    +UVM_VERBOSITY=UVM_MEDIUM \
	-svseed $(SEED) \

# Keep compiled libs per-run
XRUN_LIB_OPTS ?= -xmlibdirname $(RUN_DIR)/xcelium.d

# GUI options (SimVision)
XRUN_GUI_OPTS ?= \
    -gui \
    +UVM_TR_RECORD

XRUN_SIMLIB_OPTS ?=

XRUN_COV_OPTS ?=
ifeq ($(COVERAGE),1)
XRUN_COV_OPTS += -coverage U -covoverwrite -covworkdir $(COV_DIR) -covtest $(TEST)
endif

XRUN_SIMLIB_OPTS += -cdslib $(VIVADO_SIMLIB_DIR)/cds.lib -hdlvar $(VIVADO_SIMLIB_DIR)/hdl.var

.PHONY: help sim elab run gui clean distclean cov check_xilinx_assets bootstrap_xilinx_assets

help:
	@echo "Targets:"
	@echo "  make sim TEST=<uvm_test> SEED=<n>"
	@echo "  make cov  (Opens coverage GUI)"
	@echo "  make clean"
	@echo ""
	@echo "Xilinx primitive simulation defaults (VM):"
	@echo "  glbl is always included"
	@echo "  XILINX_SIM_ASSETS_DIR=$(XILINX_SIM_ASSETS_DIR)"
	@echo "  BOOTSTRAP_XILINX_ASSETS=$(BOOTSTRAP_XILINX_ASSETS)"
	@echo "  VIVADO_HOME=$(VIVADO_HOME)"
	@echo "  XRUN_DEFINE_OPTS=+define+XIL_PHY"
	@echo "  VIVADO_SIMLIB_DIR=$(VIVADO_SIMLIB_DIR)"
	@echo "  VIVADO_GLBL=$(VIVADO_GLBL)"

bootstrap_xilinx_assets:
	@sh "$(BOOTSTRAP_XILINX_ASSETS)" \
		--repo-root "$(REPO_ROOT)" \
		--assets-dir "$(XILINX_SIM_ASSETS_DIR)" \
		--simlib-dir "$(VIVADO_SIMLIB_DIR)" \
		--vivado-home "$(VIVADO_HOME)" \
		--vivado-bin "$(VIVADO_BIN)" \
		--xrun "$(XRUN)"

check_xilinx_assets:
	@if [ -z "$(VIVADO_GLBL)" ] || [ ! -f "$(VIVADO_GLBL)" ] || [ ! -f "$(VIVADO_SIMLIB_DIR)/cds.lib" ] || [ ! -f "$(VIVADO_SIMLIB_DIR)/hdl.var" ]; then \
		$(MAKE) --no-print-directory bootstrap_xilinx_assets; \
	fi
	@if [ -z "$(VIVADO_GLBL)" ] || [ ! -f "$(VIVADO_GLBL)" ]; then \
		echo "Missing glbl.v."; \
		echo "Put it under $(XILINX_SIM_ASSETS_DIR), set XILINX_VIVADO/VIVADO_HOME so it can be auto-discovered, or override VIVADO_GLBL=<path>."; \
		exit 1; \
	fi
	@if [ ! -f "$(VIVADO_SIMLIB_DIR)/cds.lib" ] || [ ! -f "$(VIVADO_SIMLIB_DIR)/hdl.var" ]; then \
		echo "Missing compiled Xilinx Xcelium libraries in $(VIVADO_SIMLIB_DIR)"; \
		echo "Generate them under $(XILINX_SIM_ASSETS_DIR) or override VIVADO_SIMLIB_DIR=<path>."; \
		exit 1; \
	fi

sim: check_xilinx_assets $(RUN_DIR)
	-$(XRUN) -f $(FILELIST) -top $(TOP) -top glbl $(XRUN_LIB_OPTS) $(XRUN_OPTS) $(XRUN_COV_OPTS) $(VIVADO_GLBL) $(XRUN_SIMLIB_OPTS) $(XRUN_DEFINE_OPTS) -l $(LOG_RUN) || echo "xrun exited with an error. Check $(LOG_RUN) for details."
	@mkdir -p $(RUN_DIR)/cov_work
	@if [ -d $(TEMP_DIR) ] && [ "$$(ls -A $(TEMP_DIR) 2>/dev/null)" ]; then \
		mv -f  $(TEMP_DIR)/* $(RUN_DIR)/cov_work; \
		echo "Coverage files moved to $(RUN_DIR)/"; \
	else \
		echo "No coverage files to move from $(TEMP_DIR)"; \
	fi

elab: check_xilinx_assets $(RUN_DIR)
	$(XRUN) -f $(FILELIST) -top $(TOP) -top glbl $(XRUN_LIB_OPTS) $(XRUN_OPTS) $(XRUN_COV_OPTS) $(VIVADO_GLBL) $(XRUN_SIMLIB_OPTS) $(XRUN_DEFINE_OPTS) -l $(LOG_ELAB) -elaborate

run: check_xilinx_assets
	-$(XRUN) -f $(FILELIST) -top $(TOP) -top glbl $(XRUN_LIB_OPTS) $(XRUN_OPTS) $(XRUN_COV_OPTS) $(VIVADO_GLBL) $(XRUN_SIMLIB_OPTS) $(XRUN_DEFINE_OPTS) -l $(LOG_RUN) || echo "xrun exited with an error. Check $(LOG_RUN) for details."
	@mkdir -p $(RUN_DIR)/cov_work
	@if [ -d $(TEMP_DIR) ] && [ "$$(ls -A $(TEMP_DIR) 2>/dev/null)" ]; then \
		mv -f  $(TEMP_DIR)/* $(RUN_DIR)/cov_work; \
		echo "Coverage files moved to $(RUN_DIR)/"; \
	else \
		echo "No coverage files to move from $(TEMP_DIR)"; \
	fi

gui: check_xilinx_assets $(RUN_DIR)
	$(XRUN) -f $(FILELIST) -top $(TOP) -top glbl $(XRUN_LIB_OPTS) $(XRUN_OPTS) $(XRUN_COV_OPTS) $(VIVADO_GLBL) $(XRUN_SIMLIB_OPTS) $(XRUN_DEFINE_OPTS) $(XRUN_GUI_OPTS) -l $(LOG_GUI)

cov:
	imc -load ./sim/usb_clk_test/cov_work/

$(RUN_DIR):
	@mkdir -p $(RUN_DIR)

clean:
	@rm -rf sim

distclean: clean
	@rm -rf xcelium.d INCA_libs waves.shm *.log *.key $(TEMP_DIR)
