# Sourced as UTF-8 by the generated ASCII startup.tcl.
encoding system utf-8
fconfigure stdout -encoding utf-8
fconfigure stderr -encoding utf-8
# Windows console channels deliver UTF-16; byte-stream pipes carry our UTF-8 input.
if {[fconfigure stdin -encoding] ne "unicode"} {
    fconfigure stdin -encoding utf-8
}

namespace eval cnflow {}

proc cnflow::save_result {project bit probes} {
    set f [open $::cn(result) w]
    fconfigure $f -encoding utf-8
    puts $f $project
    puts $f $bit
    puts $f $probes
    close $f
}

proc cnflow::check_run {name} {
    set status [get_property STATUS [get_runs $name]]
    if {![string match "*Complete*" $status]} {
        error "运行 $name 未完成，状态：$status。请查看该运行目录中的 runme.log。"
    }
}

proc cnflow::build {} {
    global cn
    set part [get_parts -quiet $cn(part)]
    if {[llength $part] != 1} { error "未找到唯一的已安装器件：$cn(part)。请核对完整型号和器件支持包。" }
    if {[file exists $cn(project_dir)]} { error "新工程目录已存在：$cn(project_dir)" }
    puts "步骤 1：创建工程、选择器件、添加设计文件和 XDC。"
    file mkdir [file dirname $cn(project_dir)]
    create_project $cn(name) $cn(project_dir) -part $part
    add_files -norecurse -fileset sources_1 $cn(sources)
    set includes {}
    foreach path $cn(sources) { lappend includes [file dirname $path] }
    set_property include_dirs [lsort -unique $includes] [get_filesets sources_1]
    add_files -norecurse -fileset constrs_1 $cn(xdc)
    set_property top $cn(top) [get_filesets sources_1]
    update_compile_order -fileset sources_1
    set project [file join $cn(project_dir) $cn(name).xpr]
    set reports [file join $cn(project_dir) reports]
    file mkdir $reports
    if {$cn(stage) == 1} {
        save_result $project {} {}
        close_project
        return
    }
    puts "步骤 2：综合。"
    launch_runs synth_1 -jobs $cn(jobs)
    wait_on_run synth_1
    check_run synth_1
    if {$cn(stage) == 2} {
        open_run synth_1
        report_utilization -file [file join $reports utilization.rpt]
        save_result $project {} {}
        close_project
        return
    }
    puts "步骤 3：实现并生成 bit。保留 Vivado 原有 DRC 检查。"
    launch_runs impl_1 -to_step write_bitstream -jobs $cn(jobs)
    wait_on_run impl_1
    check_run impl_1
    set bit [file join [get_property DIRECTORY [get_runs impl_1]] $cn(top).bit]
    if {![file exists $bit]} { error "实现结束但没有找到 bit 文件：$bit" }
    open_run impl_1
    report_timing_summary -file [file join $reports timing_summary.rpt]
    report_utilization -file [file join $reports utilization.rpt]
    report_drc -file [file join $reports drc.rpt]
    set probes {}
    if {[llength [get_debug_cores -quiet]] > 0} {
        set probes [file join $cn(project_dir) $cn(top).ltx]
        write_debug_probes $probes
    }
    set worst [get_timing_paths -quiet -max_paths 1 -setup]
    if {[llength $worst] && [get_property SLACK $worst] < 0} {
        puts "注意：bit 已生成，但建立时间时序尚未收敛。请检查 reports/timing_summary.rpt。"
    }
    save_result $project $bit $probes
    puts "bit 已生成：$bit"
    close_project
}

proc cnflow::choose {items label} {
    if {![llength $items]} { error "未找到$label，请检查开发板供电、JTAG 连接和驱动。" }
    puts "检测到的$label："
    set i 0
    foreach item $items { incr i; puts "  $i. $item" }
    if {[llength $items] == 1} { return [lindex $items 0] }
    while {1} {
        puts "请选择$label 的编号（Q 取消）："
        flush stdout
        if {[gets stdin answer] < 0 || [string equal -nocase [string trim $answer] q]} {
            return {}
        }
        set answer [string trim $answer]
        if {[string is integer -strict $answer] && $answer >= 1 && $answer <= [llength $items]} {
            return [lindex $items [expr {$answer - 1}]]
        }
        puts "编号无效，请重新输入。"
    }
}

proc cnflow::program {} {
    global cn
    open_hw_manager
    connect_hw_server -url $cn(server)
    set target [choose [get_hw_targets -quiet] 硬件目标]
    if {$target eq {}} { puts "已取消。"; return 0 }
    open_hw_target $target
    set device [choose [get_hw_devices -quiet] FPGA器件]
    if {$device eq {}} { puts "已取消。"; return 0 }
    current_hw_device $device
    puts "目标：$target"
    puts "器件：$device"
    puts "bit：$cn(bit)"
    puts "调试探针：$cn(probes)"
    puts "核对以上信息，输入 PROGRAM 执行 FPGA 下载；回车取消："
    flush stdout
    if {[gets stdin answer] < 0 || [string trim $answer] ne "PROGRAM"} {
        puts "已取消，未执行烧录。"
        return 0
    }
    set_property PROGRAM.FILE $cn(bit) $device
    if {$cn(probes) ne {}} { set_property PROBES.FILE $cn(probes) $device }
    program_hw_devices $device
    refresh_hw_device $device
    puts "FPGA 下载完成，正在打开硬件调试界面。"
    return 1
}

if {[info exists ::cn(action)]} {
    switch -- $::cn(action) {
        parts {
            set parts [get_parts -quiet $::cn(pattern)]
            puts "匹配到 [llength $parts] 个已安装器件（最多显示 60 个）："
            foreach part [lrange $parts 0 59] { puts $part }
            if {[llength $parts] > 60} { puts "请使用更具体的查询，例如 ?xc7a35*。" }
        }
        build { cnflow::build }
        hardware_gui {
            if {$::cn(project_file) ne {}} { open_project $::cn(project_file) }
            open_hw_manager
            puts "已打开硬件管理器。点击 Open Target 连接开发板，Program Device 选择 bit/ltx。"
        }
        program {
            if {![cnflow::program]} { exit 0 }
            start_gui
        }
        default { error "未知操作：$::cn(action)" }
    }
}
