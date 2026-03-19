# DPHY Vivado Flow (Zybo Z7-10)

This repo includes a reproducible Vivado flow for project `DPHY`.

- Project name: `DPHY`
- Part: `xc7z010clg400-1`
- Board part: `digilentinc.com:zybo-z7-10:part0:1.0`
- Sources: all `*.sv` and `*.svh` files in `src/`

## 1) Run synthesis from existing project (batch)

This flow reuses an existing project at `build/vivado_dphy/DPHY.xpr`.
It does not create a new project.

Pass the exact top module name you want to synthesize:

```bash
vivado -mode batch -source scripts/vivado_synth.tcl -tclargs -top <top_module>
```

Makefile wrapper (recommended):

```bash
make syn TOP=<top_module>
```

Examples:

```bash
vivado -mode batch -source scripts/vivado_synth.tcl -tclargs -top clock_lane
vivado -mode batch -source scripts/vivado_synth.tcl -tclargs -top tx_data_lane
```

Optional args:

```bash
-build_dir <path> -project DPHY -src_dir <path> -jobs 8
```

## 2) Open the project in GUI

Option A: open with script:

```bash
vivado -mode gui -source scripts/open_project.tcl
```

Makefile wrapper:

```bash
make open
```

Set top while opening:

```bash
vivado -mode gui -source scripts/open_project.tcl -tclargs -top <top_module>
```

Makefile wrapper:

```bash
make open_top TOP=<top_module>
```

Option B: open directly:

```bash
vivado build/vivado_dphy/DPHY.xpr
```

## 3) Change top and run synthesis in GUI

In Vivado GUI:

1. Open `DPHY.xpr`.
2. In Sources, right-click your module and select **Set as Top**.
3. Click **Run Synthesis**.

You can also use Tcl Console in GUI:

```tcl
set_property top <top_module> [get_filesets sources_1]
update_compile_order -fileset sources_1
reset_run synth_1
launch_runs synth_1 -jobs 8
```
