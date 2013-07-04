#
# Copyright 1991-2011 Mentor Graphics Corporation
#
# All Rights Reserved.
#
# THIS WORK CONTAINS TRADE SECRET AND PROPRIETARY INFORMATION
# WHICH IS THE PROPERTY OF MENTOR GRAPHICS CORPORATION
# OR ITS LICENSORS AND IS SUBJECT TO LICENSE TERMS.
#
# To run this example, bring up the simulator and type the following at the prompt:
#     do run.do
# or, to run from a shell, type the following at the shell prompt:
#     vsim -c -do run.do
# (omit the "-c" to see the GUI while running from the shell)
#

# Create the library.
if [file exists work] {
    vdel -all
}
vlib work

# Get the simulator installation directory.
quietly set INSTALL_HOME [file dirname [file normalize $::env(MODEL_TECH)]]

# Set the compiler and linker paths.
if {$tcl_platform(platform) eq "windows"} {
	source $INSTALL_HOME/examples/c_windows/setup/setup_compiler_and_linker_paths_mingwgcc.tcl
} else {
	source $INSTALL_HOME/examples/c_posix/setup/setup_compiler_and_linker_paths_gcc.tcl
}

# Compile the C source(s).
echo $CC tester.c
eval $CC tester.c
if { [catch {eval $CC tester.c} result] } {
	echo $result
}
echo $LD tester.so tester.o $MTIPLILIB
if { [catch {eval $LD tester.so tester.o $MTIPLILIB} result] } {
	echo $result
}

# Compile the VHDL source(s).
vcom xcvr.vhd
vcom tester.vhd
vcom test_circuit.vhd

# Simulate the design.
vsim testbed
onerror {resume}
add wave *
run 500

quit -f
