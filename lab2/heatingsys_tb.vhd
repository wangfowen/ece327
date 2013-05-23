------------------------------------------------------------------------
-- heating system testbench
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.heat_pkg.all;

entity heatingsys_tb is
end entity;

architecture main of heatingsys_tb is
	signal cur_temp 	: signed(7 downto 0);
	signal des_temp		: signed(7 downto 0);
	signal reset 			: std_logic;
	signal clock 			: std_logic;
	signal heatmode		: heat_ty;
begin
	controller : entity work.heatingsys(main)
		port map (
			i_cur_temp 		=> cur_temp,
			i_des_temp		=> des_temp,
			i_reset 			=> reset,
			i_clock				=> clock,
			o_heatmode		=> heatmode
		);

	-- Clock period: 20 ns
	clock_process : process
	begin 
		wait for 10 ns;
		clock <= '0';
		wait for 10 ns;
		clock <= '1';
	end process;
	
	-- In this test bench, we will be increasing the value of the desired temperature
	-- This will allow us to see if the temperature difference is accurate
	process
	begin
		-- Wait for output state to change from undefined to off state
		wait for 10 ns;
		cur_temp <= to_signed(0,8); des_temp <= to_signed(0,8) ; reset <= '0';
		wait for 40 ns;
		
		-- Test OFF state (no change)
		cur_temp <= to_signed(-1,8); des_temp <= to_signed(1,8) ; reset <= '0';
		wait for 40 ns;
		
		-- Test OFF-->LOW
		cur_temp <= to_signed(-1,8); des_temp <= to_signed(2,8) ; reset <= '0';
		wait for 40 ns;
		
		-- Test LOW state (no change)
		cur_temp <= to_signed(1,8); des_temp <= to_signed(3,8) ; reset <= '0';
		wait for 40 ns;
		
		-- Test LOW-->OFF
		cur_temp <= to_signed(3,8); des_temp <= to_signed(4,8) ; reset <= '0';
		wait for 40 ns;
		
		-- Test OFF-->HIGH
		cur_temp <= to_signed(0,8); des_temp <= to_signed(5,8) ; reset <= '0';
		wait for 40 ns;
		
		-- Test HIGH state (no change)
		cur_temp <= to_signed(3,8); des_temp <= to_signed(6,8) ; reset <= '0';
		wait for 40 ns;
		
		-- Test HIGH-->LOW-->OFF
		cur_temp <= to_signed(7,8); des_temp <= to_signed(7,8) ; reset <= '0';
		wait for 80 ns;

		-- Test OFF-->LOW
		cur_temp <= to_signed(4,8); des_temp <= to_signed(8,8) ; reset <= '0';
		wait for 40 ns;		
		
		-- Test LOW-->HIGH
		cur_temp <= to_signed(2,8); des_temp <= to_signed(9,8) ; reset <= '0';
		wait for 40 ns;	
		
		-- Test reset from OFF state
		cur_temp <= to_signed(5,8); des_temp <= to_signed(9,8) ; reset <= '1';
		wait for 40 ns;	

		-- Test OFF-->LOW
		cur_temp <= to_signed(5,8); des_temp <= to_signed(9,8) ; reset <= '0';
		wait for 40 ns;	
		
		-- Test reset from LOW state
		cur_temp <= to_signed(5,8); des_temp <= to_signed(9,8) ; reset <= '1';
		wait for 40 ns;		
		
		-- Test OFF-->HIGH
		cur_temp <= to_signed(0,8); des_temp <= to_signed(9,8) ; reset <= '1';
		wait for 40 ns;		

		-- Test reset from HIGH state
		cur_temp <= to_signed(0,8); des_temp <= to_signed(9,8) ; reset <= '1';
		wait for 100 ns;		

	end process;
end architecture;
