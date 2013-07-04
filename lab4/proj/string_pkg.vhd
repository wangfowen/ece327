library ieee;
use ieee.std_logic_1164.all;

library STD;
use std.textio.all;

package string_pkg is

  function to_string ( v : std_logic ) return string;
    
  function to_string ( n : integer range -1024 to 1024   ) return string;
    
  function nat_to_string ( nat : natural range 0 to 1024 ) return string;
    
end string_pkg;

package body string_pkg is

  function to_string ( v : std_logic ) return string is
  begin
    case v is
      when '1' => return "1";
      when '0' => return "0";
      when 'H' => return "H";
      when 'L' => return "L";
      when 'X' => return "X";
      when '-' => return "-";
      when 'U' => return "U";
      when others => return "?";
    end case;
  end to_string;
  
  function digit_to_char ( d : integer ) return character is
  begin
    return ( character'val( character'pos('0') + d ) );
  end digit_to_char;
    
  function nat_to_string ( nat : natural range 0 to 1024) return string is
    variable res : string(1 to 4);
    variable n   : natural;
  begin
    n := nat;
    for i in 4 downto 1 loop
      res(i) := digit_to_char( n mod 10);
      n   := n / 10;
    end loop;
    return res;
  end nat_to_string;

  function to_string ( n : integer range -1024 to 1024) return string is
  begin
    if 0 > n then
      return("-" & nat_to_string( abs(n)));
    else
      return(" " & nat_to_string( natural( n )));
    end if;
  end to_string;

end string_pkg;
  
