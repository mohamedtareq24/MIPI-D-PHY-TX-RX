#!/usr/bin/env sh

set -eu

repo_root=
assets_dir=
simlib_dir=
vivado_home=
vivado_bin=
xrun_bin=xrun

while [ "$#" -gt 0 ]; do
    case "$1" in
        --repo-root)
            repo_root="$2"
            shift 2
            ;;
        --assets-dir)
            assets_dir="$2"
            shift 2
            ;;
        --simlib-dir)
            simlib_dir="$2"
            shift 2
            ;;
        --vivado-home)
            vivado_home="$2"
            shift 2
            ;;
        --vivado-bin)
            vivado_bin="$2"
            shift 2
            ;;
        --xrun)
            xrun_bin="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 2
            ;;
    esac
done

if [ -z "$repo_root" ] || [ -z "$assets_dir" ] || [ -z "$simlib_dir" ]; then
    echo "Missing required arguments for ensure_xilinx_sim_assets.sh" >&2
    exit 2
fi

resolve_vivado_home() {
    if [ -n "$vivado_home" ] && [ -d "$vivado_home" ]; then
        printf '%s\n' "$vivado_home"
        return 0
    fi

    if [ -n "${XILINX_VIVADO:-}" ] && [ -d "${XILINX_VIVADO}" ]; then
        printf '%s\n' "${XILINX_VIVADO}"
        return 0
    fi

    if [ -n "$vivado_bin" ] && [ -x "$vivado_bin" ]; then
        cd "$(dirname "$vivado_bin")/.." && pwd
        return 0
    fi

    if command -v vivado >/dev/null 2>&1; then
        cd "$(dirname "$(command -v vivado)")/.." && pwd
        return 0
    fi

    return 1
}

mkdir -p "$assets_dir"

resolved_vivado_home=""
if resolved_vivado_home="$(resolve_vivado_home 2>/dev/null)"; then
    echo "Using Vivado installation at $resolved_vivado_home"
else
    echo "Vivado installation was not found. Local assets will be used if already present."
fi

local_glbl="$assets_dir/glbl.v"
if [ ! -f "$local_glbl" ] && [ -n "$resolved_vivado_home" ] && [ -f "$resolved_vivado_home/data/verilog/src/glbl.v" ]; then
    cp -f "$resolved_vivado_home/data/verilog/src/glbl.v" "$local_glbl"
    echo "Copied glbl.v into $local_glbl"
fi

if [ -f "$simlib_dir/cds.lib" ] && [ -f "$simlib_dir/hdl.var" ]; then
    exit 0
fi

if [ -z "$resolved_vivado_home" ]; then
    echo "Skipping simlib generation because Vivado was not found."
    exit 0
fi

if ! command -v "$xrun_bin" >/dev/null 2>&1; then
    echo "Skipping simlib generation because xrun was not found on PATH."
    exit 0
fi

compile_tcl="$repo_root/scripts/compile_xcelium_simlib.tcl"
if [ ! -f "$compile_tcl" ]; then
    echo "Missing helper script: $compile_tcl" >&2
    exit 1
fi

mkdir -p "$simlib_dir"
vivado_cmd="$vivado_bin"
if [ -z "$vivado_cmd" ]; then
    if command -v vivado >/dev/null 2>&1; then
        vivado_cmd="$(command -v vivado)"
    else
        echo "Skipping simlib generation because vivado was not found on PATH."
        exit 0
    fi
fi

echo "Generating Xcelium simlibs under $simlib_dir"
"$vivado_cmd" -mode batch -source "$compile_tcl" -tclargs -out_dir "$simlib_dir" -xrun "$xrun_bin"
