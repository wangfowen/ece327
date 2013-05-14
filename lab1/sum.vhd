library ieee;
use ieee.std_logic_1164.all;

entity sum is
       port ( i_a, i_b, i_cin : in std_logic;
              o_sum :       out std_logic
       );
end sum;

architecture main of sum is
	begin
		o_sum <= i_a xor i_b xor i_cin;

end architecture;

-- question 1
  -- In Precision RTL, we see a generated circuit schematic of the vhd code. 
  -- The inputs are seen on the left (i_b, i_cin, i_a)
  -- These inputs drive the two XOR gates
  -- The output is displayed on the right of the schematic

