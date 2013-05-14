library ieee;
use ieee.std_logic_1164.all;

entity add2_tb is
end add2_tb;

architecture main of add2_tb is
   signal a, b : std_logic_vector(1 downto 0);
   signal cin  : std_logic;
   signal sum  : std_logic_vector(1 downto 0);
   signal cout : std_logic;
begin
  
   uut : entity work.add2(main)
     port map (
       i_a    => a,
       i_b    => b,
       i_cin  => cin,
       o_sum  => sum,
       o_cout => cout
     );

   -- insert VHDL testbench code here
   
end main;

-- question 4
-- signal | output waveform description
-- sum(0)     
-- sum(1)     
-- cout    
