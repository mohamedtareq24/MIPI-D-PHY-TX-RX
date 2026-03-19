# Vivado batch synthesis using an existing project in build_dir.
# Usage example:
# vivado -mode batch -source scripts/vivado_synth.tcl -tclargs -top clock_lane

proc get_arg {argv key default_val} {
    set idx [lsearch -exact $argv $key]
    if {$idx >= 0 && ($idx + 1) < [llength $argv]} {
        return [lindex $argv [expr {$idx + 1}]]
    }
    return $default_val
}

proc discover_modules {sv_files} {
    set modules {}
    foreach f $sv_files {
        set fh [open $f r]
        set contents [read $fh]
        close $fh

        foreach line [split $contents "\n"] {
            if {[regexp {^[ \t]*module[ \t]+([A-Za-z_][A-Za-z0-9_$]*)} $line -> mod_name]} {
                lappend modules $mod_name
            }
        }
    }
    return [lsort -unique $modules]
}

set repo_root [pwd]
set src_dir [get_arg $argv -src_dir [file normalize [file join $repo_root src]]]
set build_dir [get_arg $argv -build_dir [file normalize [file join $repo_root build vivado_dphy]]]
set project_name [get_arg $argv -project D-PHY]
set top_module [get_arg $argv -top ""]
set jobs [get_arg $argv -jobs 8]

if {$top_module eq ""} {
    puts "ERROR: Missing required argument -top <module_name>"
    exit 1
}

set xpr_path [file normalize [file join $build_dir ${project_name}.xpr]]
if {![file exists $xpr_path]} {
    puts "ERROR: Existing project not found: $xpr_path"
    puts "This flow does not create projects. Point -build_dir/-project to an existing .xpr."
    exit 1
}

open_project $xpr_path

set svh_files [lsort [glob -nocomplain [file join $src_dir *.svh]]]
set sv_files [lsort [glob -nocomplain [file join $src_dir *.sv]]]

if {[llength $svh_files] == 0 && [llength $sv_files] == 0} {
    puts "ERROR: No source files found in $src_dir"
    exit 1
}

set available_modules [discover_modules $sv_files]
if {[lsearch -exact $available_modules $top_module] < 0} {
    puts "ERROR: Requested top '$top_module' was not found in $src_dir"
    puts "Available module names: [join $available_modules {, }]"
    exit 1
}

# Refresh only files under src_dir to keep project in sync without recreating it.
set src_dir_norm [file normalize $src_dir]
set current_src_files [get_files -quiet -of_objects [get_filesets sources_1]]
foreach f $current_src_files {
    set f_norm [file normalize $f]
    if {[string first $src_dir_norm $f_norm] == 0} {
        remove_files -fileset sources_1 $f
    }
}

if {[llength $svh_files] > 0} {
    add_files -norecurse -fileset sources_1 $svh_files
}
if {[llength $sv_files] > 0} {
    add_files -norecurse -fileset sources_1 $sv_files
}

set_property include_dirs [list $src_dir] [get_filesets sources_1]
set_property source_mgmt_mode None [current_project]
set_property top $top_module [get_filesets sources_1]
update_compile_order -fileset sources_1

reset_run synth_1
launch_runs synth_1 -jobs $jobs
wait_on_run synth_1

set run_status [get_property STATUS [get_runs synth_1]]
puts "synth_1 status: $run_status"
puts "Project: [file normalize [file join $build_dir ${project_name}.xpr]]"
puts "Top used: $top_module"

if {[string first "Complete" $run_status] < 0} {
    puts "ERROR: Synthesis did not complete successfully"
    exit 2
}

exit 0
