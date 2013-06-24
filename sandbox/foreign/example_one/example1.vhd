--
-- Copyright 1991-2011 Mentor Graphics Corporation
--
-- All Rights Reserved.
--
-- THIS WORK CONTAINS TRADE SECRET AND PROPRIETARY INFORMATION WHICH IS THE PROPERTY OF 
-- MENTOR GRAPHICS CORPORATION OR ITS LICENSORS AND IS SUBJECT TO LICENSE TERMS.
--   

entity cif is
    port(   enum_a    : in boolean := false;
            enum_b    : in boolean := false;
            enum_out  : out boolean;
            int_a     : in integer := 0;
            int_b     : in integer := 0;
            int_out   : out integer;
            float_a   : in real := 0.0;
            float_b   : in real := 0.0;
            float_out : out real;
            array_a   : in bit_vector(7 downto 0) := "00000000";
            array_b   : in bit_vector(7 downto 0) := "00000000";
            array_out : out bit_vector(7 downto 0)
        );
end;

architecture only of cif is
    attribute foreign : string;
    attribute foreign of only : architecture is "cif_init ./example1.so";
begin
-- The C code for the foreign architecture
-- mimics the VHDL statements in the rtl architecture.
end;

architecture rtl of cif is
begin
  enum_out  <= enum_a and enum_b;
  int_out   <= int_a + int_b;
  float_out <= float_a + float_b;
  array_out <= array_a and array_b;
end;

-- -- --

entity verification is
end verification;

architecture comparison of verification is

  component cif
    port(   enum_a    : in boolean;
            enum_b    : in boolean;
            enum_out  : out boolean;
            int_a     : in integer;
            int_b     : in integer;
            int_out   : out integer;
            float_a   : in real;
            float_b   : in real;
            float_out : out real;
            array_a   : in bit_vector(7 downto 0);
            array_b   : in bit_vector(7 downto 0);
            array_out : out bit_vector(7 downto 0)
        );
  end component;

  signal mismatch     : boolean := false;
  signal enum_a       : boolean := false;
  signal enum_b       : boolean := false;
  signal enum_u1_out  : boolean := false;
  signal enum_u2_out  : boolean := false;
  signal int_a        : integer := 0;
  signal int_b        : integer := 0;
  signal int_u1_out   : integer := 0;
  signal int_u2_out   : integer := 0;
  signal float_a      : real    := 0.0;
  signal float_b      : real    := 0.0;
  signal float_u1_out : real    := 0.0;
  signal float_u2_out : real    := 0.0;
  signal array_a      : bit_vector(7 downto 0) := "01001100";
  signal array_b      : bit_vector(7 downto 0) := "10101010";
  signal array_u1_out : bit_vector(7 downto 0) := "00000000";
  signal array_u2_out : bit_vector(7 downto 0) := "00000000";

  for u1 : cif use entity work.cif(only);
  for u2 : cif use entity work.cif(rtl);

begin

  U1 : cif
       port map ( enum_a,  enum_b,  enum_u1_out,
                  int_a,   int_b,   int_u1_out,
                  float_a, float_b, float_u1_out,
                  array_a, array_b, array_u1_out
                );

  U2 : cif
       port map ( enum_a,  enum_b,  enum_u2_out,
                  int_a,   int_b,   int_u2_out,
                  float_a, float_b, float_u2_out,
                  array_a, array_b, array_u2_out
                );

-- Stimulus

  process
    begin
      wait for 20 ns;
      enum_a  <= not enum_a;
      int_a   <= int_a + 1;
      float_a <= float_a + 1.1;
      array_a(7) <= array_a(6);
      array_a(6) <= array_a(5);
      array_a(5) <= array_a(4);
      array_a(4) <= array_a(3);
      array_a(3) <= array_a(2);
      array_a(2) <= array_a(1);
      array_a(1) <= array_a(0);
      array_a(0) <= array_a(7);
      wait for 20 ns;
      enum_b  <= not enum_b;
      int_b   <= int_b + 2;
      float_b <= float_b + 2.3;
      array_b(7) <= array_b(0);
      array_b(6) <= array_b(7);
      array_b(5) <= array_b(6);
      array_b(4) <= array_b(5);
      array_b(3) <= array_b(4);
      array_b(2) <= array_b(3);
      array_b(1) <= array_b(2);
      array_b(0) <= array_b(1);
    end process;

-- Comparison

  mismatch <= (enum_u1_out  /= enum_u2_out)  OR
              (int_u1_out   /= int_u2_out)   OR
              (float_u1_out /= float_u2_out) OR
              (array_u1_out /= array_u2_out);

end comparison;
