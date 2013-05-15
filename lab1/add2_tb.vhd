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

  process
  begin
    a(0) <= '0'; b(0) <= '0'; a(1) <= '0'; b(1) <= '0'; cin <= '0';
    wait for 10 ns;
    a(0) <= '1'; b(0) <= '0'; a(1) <= '1'; b(1) <= '0'; cin <= '0';
    wait for 10 ns;
    a(0) <= '1'; b(0) <= '1'; a(1) <= '0'; b(1) <= '0'; cin <= '1';
    wait for 10 ns;
    a(0) <= '0'; b(0) <= '0'; a(1) <= '1'; b(1) <= '1'; cin <= '1';
    wait for 10 ns;
  end process;

end main;

-- question 4
-- signal | output waveform description
-- sum(0)   0 1 1 1
-- sum(1)   0 1 1 0
-- cout     0 0 0 1
