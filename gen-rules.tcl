#!/usr/bin/env tclsh
#
# Usage: gen-rules.tcl [--set-version <date>]
#
# <date> should be in the form YYYYMMDD
#
# Config files are expected to be in subfolder "usb_modeswitch.d"
#
# A config file is expected to have one comment line containing
# a model name or other concise device specifications


# Default version string
set version "20160803"

# Devices excluded from Huawei catch-all rule
set x_huaweiList {12d1:1573 12d1:15c1}

if {[lindex $argv 0] == "--set-version" && [regexp {\d\d\d\d\d\d\d\d} [lindex $argv 1]]} {
	set version [lindex $argv 1]
}

set template {ATTR{idVendor}=="+##+", ATTR{idProduct}=="#++#", TAG+="usb_modeswitch"}

if {![file isdirectory usb_modeswitch.d]} {
	puts "No \"usb_modeswitch.d\" subfolder found"
	exit
}

set filelist [lsort [glob -nocomplain ./usb_modeswitch.d/*]]
if {[llength $filelist] == 0} {
	puts "The \"usb_modeswitch.d\" subfolder is empty"
	exit
}

set wc [open "40-usb_modeswitch.rules" w]

# Writing file header with given version

puts -nonewline $wc {# Part of usb-modeswitch-data, version }
puts $wc $version
puts $wc {#
# Works with usb_modeswitch versions >= 2.4.0 (extension of StandardEject)
#
ACTION!="add|change", GOTO="modeswitch_rules_end"

SUBSYSTEM!="usb", ACTION!="add",, GOTO="modeswitch_rules_end"

# Generic entry for most Huawei devices, excluding Android phones
ATTRS{idVendor}=="12d1", ATTRS{manufacturer}!="Android", ATTR{bInterfaceNumber}=="00", ATTR{bInterfaceClass}=="08", TAG+="usb_modeswitch"}

set vendorList ""
set dvid ""

foreach idfile $filelist {
	if {![regexp -nocase {./([0-9A-F]{4}:[0-9A-F]{4})} $idfile d id]} {continue}
	if {[regexp -nocase {^12d1:} $id] && [lsearch $x_huaweiList $id] == -1} {continue}
	if [info exists entry($id)] {
		append entry($id) ", "
	}
	set rc [open $idfile r]
	set buffer [read $rc]
	close $rc
	foreach line [split $buffer \n] {
		set comment {}
		regexp {# (.*)} $line d comment
		if {[string length $comment] > 0} {
			append entry($id) [string trim $comment]
			break
		}
	}
}
foreach id_entry [lsort [array names entry]] {
	set id [split $id_entry :]
	set rule [regsub {\+##\+} $template [lindex $id 0]]
	set rule [regsub {#\+\+#} $rule [lindex $id 1]]
	puts $wc "\n# $entry($id_entry)\n$rule"
}

puts $wc {
LABEL="modeswitch_rules_end"}
close $wc
