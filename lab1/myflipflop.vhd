library ieee;
use ieee.std_logic_1164.all;

entity myflipflop is
  port(  i_clock   -- clock
       , i_d       -- flip-flop input
       , i_ce      -- flip-flop chip enable
       , i_reset   -- flip-flop reset
       , i_sel     -- mux selector 
       , i_d2      -- the second data input
       : in std_logic; 
         o_q       -- flip-flop output for basic flop
       , o_q_a     -- flip-flop output for part (a)
       , o_q_b     -- flip-flop output for part (b)
       , o_q_c     -- flip-flop output for part (c)
       , o_q_d     -- flip-flop output for part (d)
       : out std_logic 
  );
end myflipflop;

architecture main of myflipflop is

  -- define any extra signals here

begin

  basic : process
  begin
      wait until rising_edge(i_clock);
      o_q <= i_d;
  end process; 

  proc_a : process
      -- insert code for part (a) here
  end process;

  proc_b : process
      -- insert code for part (b) here
  end process;

  proc_c : process
      -- insert code for part (c) here
  end process;

  proc_d : process
      -- insert code for part (d) here
  end process;

  -- place any extra code or processes here

end architecture;
