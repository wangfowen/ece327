------------------------------------------------------------------------
-- constants and types for the finite-impulse response filter
------------------------------------------------------------------------
  
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

------------------------------------------------------------------------

package fir_synth_pkg is

  --------------------------------------------------------------
  -- convert unsigned 4 bit number to seven-segment display
  
  function to_sevenseg( digit : unsigned(3 downto 0) )
    return std_logic_vector;
  
  --------------------------------------------------------------
  -- 16 bit signed words
  -- 
  -- interpreted as twos-complement fixed-point numbers between
  -- -0x8.000 and +0x7.000,
  
  subtype word is signed( 15 downto 0 );

  constant num_bits_mantissa : natural := 4;
  
  type word_vector is array( natural range <> ) of word;

  --------------------------------------------------------------

  constant num_taps : natural := 17;

  -- constant lpcoef : word_vector( 1 to num_taps ) :=
  --   ( X"0900", X"0600", X"0700", X"0800", X"0A00", X"0B00",
  --     X"0C00", X"0C00", X"0C00", X"0C00", X"0C00",
  --     X"0B00", X"0A00", X"0800", X"0700", X"0600", X"0900"
  --   );

  constant lpcoef : word_vector( 1 to num_taps ) :=
    ( X"0240", X"0180", X"01C0", X"0200", X"0280", X"02C0",
      X"0300", X"0300", X"0300", X"0300", X"0300",
      X"02C0", X"0280", X"0200", X"01C0", X"0180", X"0240"
    );

  --------------------------------------------------------------

  function mult( a, b : word ) return word;
  function "sra" (v : word; n : natural) return word;
  
  --------------------------------------------------------------

  subtype display        is std_logic_vector( 15 downto 0 );
  type    display_vector is array( natural range <> ) of display;
  
  constant frequency_map     : display_vector( 0 to 127 );
  
  --------------------------------------------------------------
  -- Precision RTL attribute
  -- forces a signal to be implemented in FPGA cells,
  -- rather than a RAM block
  --
  attribute logic_block : boolean;
  
  --------------------------------------------------------------

end package;

------------------------------------------------------------------------

package body fir_synth_pkg is
  
  --------------------------------------------------------------
  
  function to_sevenseg( digit : unsigned(3 downto 0))
    return std_logic_vector
  is
    variable result : std_logic_vector( 6 downto 0 );
  begin
    case digit is
      when X"0" => result := "1000000";
      when X"1" => result := "1111001";
      when X"2" => result := "0100100";
      when X"3" => result := "0110000";
      when X"4" => result := "0011001";
      when X"5" => result := "0010010";
      when X"6" => result := "0000010";
      when X"7" => result := "1111000";
      when X"8" => result := "0000000";
      when X"9" => result := "0011000";
      when X"A" => result := "0001000";
      when X"B" => result := "0000011";
      when X"C" => result := "1000110";
      when X"D" => result := "0100001";
      when X"E" => result := "0000110";
      when X"F" => result := "0001110";
      when others  => result := (others => 'X');
    end case;
    return result;
  end function;

  --------------------------------------------------------------
  
  function "sra" ( v : word; n : natural ) return word is
  begin
    return word( shift_right( signed(v), n ) );
  end function;

  --------------------------------------------------------------

  -- fixed point multiplication where all bits are part of the fraction
  function mult( a, b : word ) return word is
    variable full_res : signed( 31 downto 0 );
    variable res      : word;
  begin
    full_res := a * b;
    res      := full_res( 31-num_bits_mantissa downto 16-num_bits_mantissa );
    return res;
  end function;

  
  function mult_v1( a, b : word ) return word is
    variable a_tmp, b_tmp : signed( 7 downto 0 );
    variable full_res : signed( 31 downto 0 );
    variable res : word;
  begin
    a_tmp    := a(15 downto 8);
    b_tmp    := b(15 downto 8);
    full_res := resize(a_tmp, 16) * resize(b_tmp, 16);
    res      := full_res( 15 downto 0 );
    return res;
    -- would be nice to do the following, but it's not legal VHDL:
    -- return (resize(a(7 downto 0), 16) * return(b(7 downto 0), 16))(15 downto 0);
  end function;

  -- !!MDA
  -- integer multiplier, reports overflow
  function mult_v2( a, b : word ) return word is
    variable full_res : signed( 31 downto 0 );
    variable res, hi_res : word;
    variable sgn_spec : std_logic;
  begin
    full_res := a * b;
    res      := full_res( 15 downto 0 );
    ----------------------------------------------------    
    if full_res > 2**15 - 1 or full_res < -2**15 then 
      report ("Overflow: "
              & integer'image( to_integer( a ) )
              & " * "
              & integer'image( to_integer( b ) )
              & " = "
              & integer'image( to_integer( full_res ) )
              & " /= "
              & integer'image( to_integer( res ) ) );
    end if;
    ----------------------------------------------------
    return res;
  end function;

  --------------------------------------------------------------
  -- frequency map
  --
  -- converts an increment amount for the address into sine-wave ROM
  -- into a hex number that is displayed on the board
  --
  -- NOTE: the number that is displayed is interpreted as decimal
  
  constant frequency_map : display_vector( 0 to 127 ) :=
    (
      x"0019", x"0028", x"0038", x"0047", x"0056", x"0066", x"0075", x"0084",
      x"0094", x"0103", x"0113", x"0122", x"0131", x"0141", x"0150", x"0159",
      x"0169", x"0178", x"0188", x"0197", x"0206", x"0216", x"0225", x"0234",
      x"0244", x"0253", x"0263", x"0272", x"0281", x"0291", x"0300", x"0309",
      -- 32
      x"0319", x"0328", x"0338", x"0347", x"0356", x"0366", x"0375", x"0384",
      x"0394", x"0403", x"0413", x"0422", x"0431", x"0441", x"0450", x"0459",
      x"0469", x"0478", x"0488", x"0497", x"0506", x"0516", x"0525", x"0534",
      x"0544", x"0553", x"0563", x"0572", x"0581", x"0591", x"0600", x"0609",
      -- 64
      x"0619", x"0628", x"0638", x"0647", x"0656", x"0666", x"0675", x"0684",
      x"0694", x"0703", x"0713", x"0722", x"0731", x"0741", x"0750", x"0759",
      x"0769", x"0778", x"0788", x"0797", x"0806", x"0816", x"0825", x"0834",
      x"0844", x"0853", x"0863", x"0822", x"0881", x"0891", x"0900", x"0909",
      -- 96
      x"0919", x"0928", x"0938", x"0947", x"0956", x"0966", x"0975", x"0984",
      x"0994", x"1003", x"1013", x"1022", x"1031", x"1041", x"1050", x"1059",
      x"1069", x"1078", x"1088", x"1097", x"1106", x"1116", x"1125", x"1134",
      x"1144", x"1153", x"1163", x"1172", x"1181", x"1191", x"1200", x"1209" );
      -- 128

end fir_synth_pkg;
