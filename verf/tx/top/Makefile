# Xcelium/XRUN Makefile for the integrated TX-PHY environment (behavioral analog).
# For the Xilinx-primitive analog model use ANALOG=xil (needs compiled simlibs +
# glbl, as in ../tx_clock_lane_uvc/Makefile).

XRUN     ?= xrun
TOP      ?= tx_phy_tb_top
TEST     ?= tx_phy_smoke_test
SEED     ?= 1
COVERAGE ?= 0
ANALOG   ?= beh

# Speed up iteration by shrinking the clock-lane init count (default RTL: 1999).
# Set FAST=1 for a quick smoke; leave unset for realistic init timing.
FAST     ?= 0
FAST_DEF :=
ifeq ($(FAST),1)
FAST_DEF := +define+TX_INIT_TIME=40
endif

FILELIST ?= ./tb/run.f
RUN_DIR  ?= sim/$(TEST)

XRUN_OPTS ?= -64bit -sv -access +rwc \
             +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=UVM_MEDIUM -svseed $(SEED)

XRUN_DEFINE_OPTS :=
ifeq ($(ANALOG),xil)
XRUN_DEFINE_OPTS += +define+XIL_PHY
endif

XRUN_COV_OPTS :=
ifeq ($(COVERAGE),1)
XRUN_COV_OPTS += -coverage U -covoverwrite -covtest $(TEST)
endif

.PHONY: sim elab clean

sim: $(RUN_DIR)
	$(XRUN) -f $(FILELIST) -top $(TOP) $(XRUN_OPTS) $(XRUN_COV_OPTS) \
		$(XRUN_DEFINE_OPTS) $(FAST_DEF) -l $(RUN_DIR)/xrun.log

elab: $(RUN_DIR)
	$(XRUN) -f $(FILELIST) -top $(TOP) $(XRUN_OPTS) \
		$(XRUN_DEFINE_OPTS) $(FAST_DEF) -elaborate -l $(RUN_DIR)/xrun_elab.log

$(RUN_DIR):
	@mkdir -p $(RUN_DIR)

clean:
	@rm -rf sim xcelium.d INCA_libs waves.shm *.log *.key
