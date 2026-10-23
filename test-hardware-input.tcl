# Offline interaction test: hardware API calls below are replaced inside THIS test process.
# Never source this test into an active Hardware Manager session.
source -encoding utf-8 [file join [file dirname [info script]] flow.tcl]
if {[catch {
    set confirm_only [expr {[lindex $argv 0] eq "confirm-only"}]
    if {!$confirm_only} {
        if {[cnflow::choose {target0 target1} Target] ne "target1"} { error "Wrong selection" }
        if {[cnflow::choose {target0 target1} Target] ne {}} { error "Cancel ignored" }
        if {![catch {cnflow::choose {} Target}]} { error "Missing hardware was accepted" }
    }

    proc open_hw_manager {} {}
    proc connect_hw_server {args} {}
    proc get_hw_targets {args} { return {offline_target} }
    proc open_hw_target {target} {}
    proc get_hw_devices {args} { return {offline_device} }
    proc current_hw_device {device} {}
    proc set_property {args} {}
    proc refresh_hw_device {device} {}
    proc program_hw_devices {device} {
        if {$device ne "offline_device"} { error "Wrong programming target" }
        incr ::program_calls
    }
    set ::cn(server) offline
    set ::cn(bit) offline.bit
    set ::cn(probes) {}
    set ::program_calls 0
    if {!$confirm_only && ([cnflow::program] != 0 || $::program_calls != 0)} {
        error "Programming happened on cancel"
    }
    if {[cnflow::program] != 1 || $::program_calls != 1} { error "Explicit PROGRAM was not honored" }
    puts "PASS: offline hardware selection, no-target failure, cancellation and PROGRAM confirmation"
    exit 0
} message options]} {
    puts stderr $message
    puts stderr [dict get $options -errorinfo]
    exit 1
}
