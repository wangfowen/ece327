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

onerror {resume}
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
quietly set CC_OPTION  -freg-struct-return
if [regexp sun* $tcl_platform(machine) ] {
   if { $tcl_platform(wordSize) eq "4"  }  {
      quietly set CC_OPTION ""
   } 
} 

echo $CC $CC_OPTION foreignsp.c
eval $CC $CC_OPTION foreignsp.c

echo $LD foreignsp.so foreignsp.o $MTIPLILIB
eval $LD foreignsp.so foreignsp.o $MTIPLILIB

# Compile the VHDL source(s).
vcom foreignsp.vhd

# Simulate the design.
vsim test -voptargs=+acc=v
view source
view process
view variables
add wave /test/p1/int
add wave /test/p1/enum
add wave /test/p1/r
add wave /test/p1/s
add wave /test/p1/rec
add wave /test/p1/ivar
add wave /test/p1/rvar
add wave /test/p1/tvar
run 300
bp foreignsp.vhd 129
step

quit -f
