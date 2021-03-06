------------------------------------------------------------------------
-- fir test bench
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fir_synth_pkg.all;

entity fir_tb is
end entity;

------------------------------------------------------------------------

architecture main of fir_tb is
 	signal clock			: std_logic;
 	signal in_data		: word;
	signal out_data		: word;

begin

		averager : entity work.fir(low_pass)
		port map (
			o_data				=> out_data,
			i_data				=> in_data,
			clk						=> clock
		);
 	
	-- Clock period: 20 ns
	clock_process : process
	begin 
		wait for 10 ns;
		clock <= '0';
		wait for 10 ns;
		clock <= '1';
	end process;

	test : process
	begin
		-- Wait for steady-state output
		wait until rising_edge(clock);
    in_data <= x"0000";
		
    for i in 1 to num_taps loop
      wait until rising_edge(clock);
    end loop;
      
    -- Step!
    in_data <= x"1000";

    -- Back to 0
		wait until rising_edge(clock);
    in_data <= x"0000";
	 
    for i in 1 to num_taps loop
      wait until rising_edge(clock);
    end loop;
    
    wait for 200 ns;
  end process;
  
end architecture;
------------------------------------------------------------------------

