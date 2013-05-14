library ieee;
use ieee.std_logic_1164.all;

entity carry is
       port ( i_x, i_y, i_cin : in std_logic;
              o_cout :       out std_logic
       );
end carry;

architecture main of carry is
  begin
    o_cout <= (i_x and i_y) or (i_x and i_cin) or (i_y and i_cin);
end architecture;
