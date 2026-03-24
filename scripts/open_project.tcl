# Open or create a Vivado project for Zybo Z7-10 and sync src files.
# Usage example:
# vivado -mode gui -source scripts/open_project.tcl -tclargs -top clock_lane

proc get_arg {argv key default_val} {
    set idx [lsearch -exact $argv $key]
    if {$idx >= 0 && ($idx + 1) < [llength $argv]} {
        return [lindex $argv [expr {$idx + 1}]]
    }
    return $default_val
}

proc collect_source_files {dir patterns} {
    set results {}
    if {![file isdirectory $dir]} {
        return $results
    }

    foreach entry [glob -nocomplain -directory $dir *] {
        if {[file isdirectory $entry]} {
            set results [concat $results [collect_source_files $entry $patterns]]
        } else {
            foreach pattern $patterns {
                if {[string match $pattern [file tail $entry]]} {
                    lappend results [file normalize $entry]
                    break
                }
            }
        }
    }

    return [lsort -unique $results]
}

proc collect_include_dirs {files root_dir} {
    set include_dirs [list [file normalize $root_dir]]
    foreach f $files {
        lappend include_dirs [file dirname $f]
    }
    return [lsort -unique $include_dirs]
}

set repo_root [pwd]
set src_dir [get_arg $argv -src_dir [file normalize [file join $repo_root src]]]
set build_dir [get_arg $argv -build_dir [file normalize [file join $repo_root build vivado_dphy]]]
set project_name [get_arg $argv -project D-PHY]
set top_module [get_arg $argv -top ""]
set fpga_part [get_arg $argv -part xc7z010clg400-1]
set board_part [get_arg $argv -board_part digilentinc.com:zybo-z7-10:part0:1.0]

set xpr_path [file normalize [file join $build_dir ${project_name}.xpr]]
set svh_files [collect_source_files $src_dir [list *.svh]]
set sv_files [collect_source_files $src_dir [list *.sv]]
set include_dirs [collect_include_dirs [concat $svh_files $sv_files] $src_dir]

if {[llength $svh_files] == 0 && [llength $sv_files] == 0} {
    puts "ERROR: No source files found in $src_dir"
    exit 1
}

if {![file exists $xpr_path]} {
    file mkdir $build_dir
    create_project $project_name $build_dir -part $fpga_part -force

    if {[catch {set_property board_part $board_part [current_project]} board_err]} {
        puts "WARNING: Could not set board_part '$board_part' (board files may be missing)."
        puts "WARNING detail: $board_err"
    }

    puts "Created project: $xpr_path"
} else {
    open_project $xpr_path
    puts "Opened project: $xpr_path"
}

# Refresh sources_1 entries under src_dir to keep project files in sync.
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

set_property include_dirs $include_dirs [get_filesets sources_1]
set_property source_mgmt_mode None [current_project]
update_compile_order -fileset sources_1

if {$top_module ne ""} {
    set_property top $top_module [get_filesets sources_1]
    update_compile_order -fileset sources_1
    puts "Top set to: $top_module"
}

puts "Project ready: $xpr_path"
puts "Imported source files from: $src_dir"
puts "Run synthesis with: launch_runs synth_1 -jobs 8"
