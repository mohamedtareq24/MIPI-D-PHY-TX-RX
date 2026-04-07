proc get_arg {argv key default_val} {
    set idx [lsearch -exact $argv $key]
    if {$idx >= 0 && ($idx + 1) < [llength $argv]} {
        return [lindex $argv [expr {$idx + 1}]]
    }
    return $default_val
}

set out_dir [file normalize [get_arg $argv -out_dir ""]]
set xrun_bin [get_arg $argv -xrun xrun]

if {$out_dir eq ""} {
    puts "ERROR: Missing required argument -out_dir <path>"
    exit 1
}

set xrun_exec [auto_execok $xrun_bin]
if {$xrun_exec eq ""} {
    puts "ERROR: Could not locate xrun executable '$xrun_bin'"
    exit 1
}

set simulator_exec_path [file dirname [file normalize $xrun_exec]]
file mkdir $out_dir

puts "Compiling Xilinx simulation libraries for Xcelium"
puts "Output directory: $out_dir"
puts "xrun executable: $xrun_exec"

compile_simlib \
    -simulator xcelium \
    -simulator_exec_path $simulator_exec_path \
    -directory $out_dir \
    -language all \
    -family all \
    -library all \
    -verbose

puts "compile_simlib completed successfully"
exit 0
