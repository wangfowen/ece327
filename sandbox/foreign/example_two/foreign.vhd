--
-- Copyright 1991-2011 Mentor Graphics Corporation
--
-- All Rights Reserved.
--
-- THIS WORK CONTAINS TRADE SECRET AND PROPRIETARY INFORMATION WHICH IS THE PROPERTY OF 
-- MENTOR GRAPHICS CORPORATION OR ITS LICENSORS AND IS SUBJECT TO LICENSE TERMS.
--   

entity and_gate is
    port ( in1, in2 : in  bit;
           out1     : out bit
         );
end and_gate;

architecture only of and_gate is
    attribute foreign : string;
    attribute foreign of only : architecture is "and_gate_init ./gates.so";
begin
end;

-- -- --

entity dump_design is
end dump_design;

architecture only of dump_design is
    attribute foreign : string;
    attribute foreign of only : architecture is "dump_design_init ./dumpdes.so";
begin
end;

-- -- --

entity monitor is
end monitor;

architecture only of monitor is
    attribute foreign : string;
    attribute foreign of only : architecture is "monitor_init ./monitor.so";
begin
end;

-- -- --

entity and4 is
    port ( in1, in2 : in  bit_vector(1 to 4);
           out1     : out bit_vector(1 to 4)
         );
end;

architecture only of and4 is

    component and_gate
        port ( in1, in2 : in bit; out1 : out bit );
    end component;

    component dump_design end component;
    component monitor end component;

begin

    g1: for i in 1 to 4 generate
        u: and_gate port map( in1(i), in2(i), out1(i) );
    end generate;

    dump: dump_design;

    monit: monitor;

end;

-- -- --

entity testbench is
end testbench;

architecture a of testbench is

  component and4
    port ( in1, in2 : in  bit_vector(1 to 4);
           out1     : out bit_vector(1 to 4)
         );
  end component;

  for all : and4 use entity work.and4(only);

  signal bv1 : bit_vector( 3 downto 0 ) := "0011";
  signal bv2 : bit_vector( 3 downto 0 ) := "0110";
  signal bv3 : bit_vector( 3 downto 0 ) := "0000";

begin

  t1 : and4
       port map ( bv1, bv2, bv3 );

  process
    begin
      wait for 20 ns;
      bv1(3) <= bv1(2);
      bv1(2) <= bv1(1);
      bv1(1) <= bv1(0);
      bv1(0) <= bv1(3);
      wait for 20 ns;
      bv2(3) <= bv2(2);
      bv2(2) <= bv2(1);
      bv2(1) <= bv2(0);
      bv2(0) <= bv2(3);
    end process;

end a;

-- -- --
