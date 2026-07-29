# MIPI D-PHY TX/RX — Design & UVM Verification

Design and UVM-based functional verification of a **MIPI D-PHY v2.5** PHY with
both **transmit (TX)** and **receive (RX)** lanes, in SystemVerilog. The project
covers the digital PHY RTL, two analog front-end models (behavioral and
Xilinx-primitive), and a layered UVM verification environment with per-lane
Universal Verification Components (UVCs), virtual-sequence coordination,
scoreboards, assertions, and functional coverage.

## Highlights (CV summary)

- Implemented a **MIPI D-PHY v2.5 TX and RX PHY** in SystemVerilog (clock lane +
  data lane), supporting **High-Speed (HS) burst** transfer and **Low-Power (LP)
  escape modes** — ULPS enter/exit and remote triggers — with PPI-style
  controller interfaces.
- Built a dual analog front-end: a **behavioral analog model** for fast
  functional simulation and a **Xilinx-primitive analog model** (PLL, SerDes,
  differential drivers) for gate-accurate runs against compiled Vivado simlibs.
- Developed a **reusable UVM verification environment** structured as per-lane
  UVCs (clock-lane + data-lane agents) reused by integrated TX and RX
  top-level environments — driver / monitor / sequencer / sequence-library /
  agent split per UVC, coordinated by a **virtual sequencer + virtual
  sequences**.
- Wrote **self-checking scoreboards** (expected-vs-recovered byte/payload
  comparison), **SystemVerilog Assertions (SVA)**, and **functional coverage**
  for protocol state and HS/escape transactions.
- Verified the **HS receive datapath** end-to-end: pad-level transmitter
  emulation (LP signalling, HS clock, serialized bitstream) → analog 1:8
  deserializer → digital byte recovery (SoT 0xB8 sync) → PPI outputs, with the
  scoreboard confirming payload integrity across varied burst sizes plus ULPS
  and all four remote triggers.
- Brought up and maintained **two simulation flows** — QuestaSim (`vlog`/`vsim`)
  and Cadence Xcelium (`xrun`) — including automated Makefiles, filelists, and
  bootstrap scripts for compiling and locating the Xilinx Xcelium libraries.
- Root-caused and fixed RTL bugs found in verification (e.g. an HS timer-reload
  defect in the TX data lane; an LPDT trailing-Space drop in the TX data lane
  that caused the RX to lose the first payload bit) using a reproduce →
  minimise → fix → regression workflow.
- Built an **end-to-end loopback environment** connecting the TX and RX PHY
  top-levels through a shared analog model; four loopback tests (HS burst,
  escape/ULPS, LPDT payload, regression) all pass.

## Repository layout

```
src/
  tx/                 TX PHY RTL + analog models
    interfaces/       PPI / D-PHY pad / analog SystemVerilog interfaces
    tx_phy_top.sv, tx_clock_lane.sv, tx_data_lane.sv, tx_d_phy.sv
    analog_top.sv     behavioral analog front-end
    analog_top_xil.sv Xilinx-primitive analog front-end
  rx/                 RX PHY RTL + analog model
    interfaces/
    rx_phy_top.sv, rx_clock_lane.sv, rx_data_lane.sv, rx_d_phy.sv
    analog_rx_top.sv  behavioral analog front-end (HS 1:8 deserializer)

verf/
  common/
    mipi_spec_pkg.sv  shared golden-value package (SoT, escape commands, LPDT)
  tx/
    tx_clock_lane_uvc/  clock-lane UVC (tr/seqncr/driver/mon/agent/seq_lib + pkg)
    tx_data_lane_uvc/   data-lane UVC
    top/                integrated TX env: vseqr, vseqs, scoreboard, coverage,
                        SVA, tests, tb top  [Makefile / Makefile.questa]
  rx/
    rx_clock_lane_uvc/  clock-lane UVC
    rx_data_lane_uvc/   data-lane UVC
    top/                integrated RX env: vseqr, vseqs, scoreboard, coverage,
                        SVA, tests, tb top  [Makefile.questa]
  loop_back/            end-to-end TX→RX loopback env: scoreboard, tests, tb top
                        [Makefile.questa]

docs/                 D-PHY spec, scope, implementation & verification plans
```

Both TX and RX use the same UVC pattern: each per-lane UVC is split into
`*_tr.sv`, `*_seqncr.sv`, `*_driver.sv`, `*_mon.sv`, `*_agent.sv`,
`*_seq_lib.sv`, gathered by a thin `*_pkg.sv`; the `top/` package assembles the
UVCs with a virtual sequencer, scoreboard, and tests.

## Architecture notes

- **TX path:** controller drives the PPI; the clock-lane and data-lane UVCs apply
  PPI stimulus, the analog model serializes onto the differential lines, and a
  recovery monitor de-serializes the HS line to check SoT + payload against what
  was injected.
- **RX path:** the UVCs act as a **link-transmitter emulator** driving the pad
  side. The **clock-lane UVC free-runs the HS clock**; the **data-lane UVC times
  each HS bit to the clock edges** (bit placed on the falling edge, stable for
  the next sampling rising edge) and also drives LP escape signalling. Byte
  alignment is robust to clock phase via a 0x00 preamble + 0xB8 SoT sync rather
  than exact edge counting. A **top-level virtual sequence** coordinates the two
  lanes (start clock → data burst → stop clock).

## Bit ordering (spec-compliant)

Per **D-PHY v2.5**, the two byte streams use different bit orders, and the RTL +
verification environment follow the specification (not each other):

- **HS data — LSB-first.** The PPI transmits/receives the LSB of each byte first
  (spec §6.x PPI HS data, "the LSB will be transmitted as the first bit"). The TX
  `serializer_8to1` shifts bit[0] out first; the RX analog 1:8 deserializer lands
  the first-arrived bit in bit[0]; the RX byte path and the TX recovery
  scoreboard assemble bytes LSB-first.
- **HS SoT Leader — `0xB8`.** Spec **Table 28** defines the Leader sequence
  `00011101` (first→last). Sent LSB-first this is the byte `0xB8`, used as both
  the TX `SOT_PATTERN` and the RX `SOT_SYNC`.
- **Escape Entry Commands — value's high bit first.** Spec **Table 10** lists each
  command as a fixed pattern "first bit transmitted to last". The byte literals
  match the table read MSB→LSB, so they are serialized/deserialized MSB-first:
  `ULPS=0x1E (00011110)`, `Reset-Trigger=0x62`, `HS-Test=0x5D`, `Unknown-4=0x21`,
  `Unknown-5=0xA0`.
- **LPDT (Low-Power Data Transmission).** Entered with the escape command
  `LPDT=0xE1 (11100001)`, serialized MSB-first like every other Table 10 entry
  command. The LPDT *payload* that follows is sent **LSB-first**, one bit at a
  time as spaced-one-hot — each bit is a Mark phase (Mark-1 for `1`, Mark-0 for
  `0`) followed by a Space. The RX decodes each payload bit on the **Mark→Space**
  edge and assembles bytes LSB-first; decoding on that trailing edge is what keeps
  the exit Mark-1 (which is followed by Stop, not a Space) from being miscounted as
  a data bit. The TX/RX scoreboards check the recovered payload byte-for-byte
  against the driven bytes.

The scoreboards encode these spec values as the golden reference independent of
the RTL: the TX scoreboard checks the recovered SoT against `0xB8` and the
recovered escape command against the Table 10 value, so a bit-order regression in
the design is reported as a failure rather than silently passing.

## Running the simulations

All QuestaSim targets use `Makefile.questa`. Available targets per env:

| target | effect |
|--------|--------|
| `sim`  | compile → open Questa GUI → run (waveforms live) |
| `cli`  | compile → batch run, WLF saved for later viewing |
| `wave` | reopen saved WLF from last `cli` run |
| `clean`| remove `questa/` scratch area |

Key overrides: `TEST=<name>` `SEED=<n>` `FAST=1` (TX — shrinks clock-lane init) `COVERAGE=1` (TX — saves UCDB).

---

### TX PHY env (`verf/tx/top`)

```bash
cd verf/tx/top

# GUI — waveforms open automatically
make -f Makefile.questa sim TEST=tx_phy_smoke_test FAST=1

# Batch, then view saved WLF
make -f Makefile.questa cli TEST=tx_phy_regress_test
make -f Makefile.questa wave

# Tests: tx_phy_smoke_test  tx_phy_regress_test  tx_phy_escape_test
#        tx_phy_lpdt_test   tx_phy_inclusive_test  tx_phy_random_test
#        tx_phy_powerup_test
```

---

### RX PHY env (`verf/rx/top`)

```bash
cd verf/rx/top

# GUI
make -f Makefile.questa sim TEST=rx_phy_regress_test

# Batch, then view saved WLF
make -f Makefile.questa cli TEST=rx_phy_regress_test
make -f Makefile.questa wave

# Tests: rx_phy_base_test  rx_phy_ulps_test    rx_phy_lpdt_test
#        rx_phy_trigger_test  rx_phy_regress_test  rx_phy_inclusive_test
#        rx_phy_random_test
```

---

### Loopback env (`verf/loop_back`)

```bash
cd verf/loop_back

# GUI
make -f Makefile.questa sim TEST=loopback_regress_test

# Batch, then view saved WLF
make -f Makefile.questa cli TEST=loopback_regress_test
make -f Makefile.questa wave

# Tests: loopback_hs_test  loopback_escape_test  loopback_lpdt_test
#        loopback_regress_test
```

---

### TX clock-lane UVC — Xcelium + Xilinx primitives (`verf/tx/tx_clock_lane_uvc`)

Needs compiled Vivado simlibs. Makefile auto-bootstraps them if `vivado` is on PATH.

```bash
cd verf/tx/tx_clock_lane_uvc

make sim                           # default: ppi_clk_test_en
make gui TEST=ppi_clk_test_en      # SimVision waveform GUI
```

---

### TX PHY env — Xcelium (`verf/tx/top`)

```bash
cd verf/tx/top

make sim TEST=tx_phy_smoke_test FAST=1
make sim TEST=tx_phy_regress_test
make sim ANALOG=xil TEST=tx_phy_smoke_test    # Xilinx-primitive analog model
```

## Tools & skills demonstrated

SystemVerilog · UVM (agents, sequences, virtual sequencers, scoreboards,
analysis ports, config_db) · SystemVerilog Assertions · functional coverage ·
MIPI D-PHY protocol (HS/LP, ULPS, escape triggers, PPI) · mixed-signal modelling
· QuestaSim · Cadence Xcelium · Xilinx Vivado simulation libraries · Makefile /
filelist build automation · RTL debug & regression.
