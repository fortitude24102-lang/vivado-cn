# Run in GUI, Tcl, or batch mode. Arguments are demonstration values only.
puts "Vivado version: [version -short]"
puts "Working directory: [pwd]"
puts "Argument count: $argc"
set index 1
foreach value $argv {
    puts "Argument $index = <$value>"
    incr index
}
