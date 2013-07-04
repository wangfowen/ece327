------------------------------------------------------------------------
-- constants and types for kirsch edge detection
------------------------------------------------------------------------
  
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

package kirsch_synth_pkg is

  --------------------------------------------------------------
  -- pixel
  
  subtype pixel_ty    is unsigned(7 downto 0);

  --------------------------------------------------------------
  -- image
  
  constant image_height : natural := 256;
  constant image_width  : natural := 256;
  
  -- constant image_height : natural := 12;
  -- constant image_width  : natural := 12;
  
  type image_ty is
    array( 0 to image_height-1, 0 to image_width - 1 ) of pixel_ty;
  
  --------------------------------------------------------------
  -- directions

  subtype direction_ty   is std_logic_vector(2 downto 0);
  
  constant dir_ne : direction_ty := "110";  -- northeast
  constant dir_sw : direction_ty := "111";  -- southwest
  constant dir_n  : direction_ty := "010";  -- north
  constant dir_s  : direction_ty := "011";  -- south
  constant dir_e  : direction_ty := "000";  -- east
  constant dir_w  : direction_ty := "001";  -- west
  constant dir_nw : direction_ty := "100";  -- northwest
  constant dir_se : direction_ty := "101";  -- southeast
    
  --------------------------------------------------------------
  -- threshold for edge detection
  
  constant threshold  : integer   := 383 ;
  
  --------------------------------------------------------------
  -- circuit modes

  subtype mode_ty   is std_logic_vector(1 downto 0);
  
  constant idle  : mode_ty := "10";
  constant busy  : mode_ty := "11";
  constant reset : mode_ty := "01";
  
  --------------------------------------------------------------
  -- convert unsigned 4 bit number to seven-segment display
  
  function to_sevenseg( digit : unsigned(3 downto 0); period : std_logic)
    return std_logic_vector;
  
  --------------------------------------------------------------

end package;

package body kirsch_synth_pkg is
  function to_sevenseg( digit : unsigned(3 downto 0); period : std_logic)
    return std_logic_vector
  is
    variable tmp    : std_logic_vector( 6 downto 0 );
    variable result : std_logic_vector( 7 downto 0 );
  begin
    result(7) := not( period );
    case digit is
      when X"0" => tmp := "0000001";
      when X"1" => tmp := "1001111";
      when X"2" => tmp := "0010010";
      when X"3" => tmp := "0000110";
      when X"4" => tmp := "1001100";
      when X"5" => tmp := "0100100";
      when X"6" => tmp := "0100000";
      when X"7" => tmp := "0001111";
      when X"8" => tmp := "0000000";
      when X"9" => tmp := "0001100";
      when X"A" => tmp := "0001000";
      when X"B" => tmp := "1100000";
      when X"C" => tmp := "0110001";
      when X"D" => tmp := "1000010";
      when X"E" => tmp := "0110000";
      when X"F" => tmp := "0111000";
      when others  => tmp := (others => 'X');
    end case;
    result( 6 downto 0 ) := tmp;
    return result;
  end function;
end kirsch_synth_pkg;
