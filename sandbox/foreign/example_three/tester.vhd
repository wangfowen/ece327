--
-- Copyright 1991-2011 Mentor Graphics Corporation
--
-- All Rights Reserved.
--
-- THIS WORK CONTAINS TRADE SECRET AND PROPRIETARY INFORMATION WHICH IS THE PROPERTY OF 
-- MENTOR GRAPHICS CORPORATION OR ITS LICENSORS AND IS SUBJECT TO LICENSE TERMS.
--   

-- Model Technology C Interface Example - A "generic" tester

-- This is the VHDL source for an example tester, whose functionality
-- is implemented in C code (file "tester.c"). The tester reads a file
-- containing stimulus and response data (file "vectors") and applies the
-- data to the ports of the entity described below. 
--
-- This example is customized for testing an 8-bit bidirectional transceiver
-- with tri-statable outputs. However, it is easy to modify the example to
-- test any other device, since the C code does not have to be changed.
-- To customize this tester to test another device, do the following steps:
--     1) Change the port declaration in the tester entity to contain the
--        port names and port types for the ports you want the tester to
--        stimulate and test.
--     2) Make a new "vectors" file that uses the port names and specifies
--        times and values for the ports you want to test.
--     3) Re-compile the tester VHDL code.
--     4) Instantiate the tester in a design with the device you want to test.
--        Connect the ports of the tester to the ports of the device under test.
--     5) Compile the VHDL for the top-level circuit (containing the tester and
--        the device under test) and then simulate it. All stimulus for this
--        circuit will be taken from the "vectors" file created in step 2.

library IEEE;
use IEEE.std_logic_1164.all;

entity tester is
    port ( portDIR: out std_logic;
           portOE:  out std_logic;
           portA: inout std_logic_vector(7 downto 0);
           portB: inout std_logic_vector(7 downto 0)
         );
end tester;

architecture test_fixture of tester is
    ATTRIBUTE foreign: string;
    -- the word "verbose" in the next line is optional; it enables
    -- trace messages to go to standard output that describes what the
    -- tester is doing.
    ATTRIBUTE foreign of test_fixture: architecture is
              "tester_init ./tester.so; verbose";
begin
end test_fixture;
