library ieee;
use ieee.std_logic_1164.all;

package heat_pkg is
  subtype heat_ty is std_logic_vector(1 downto 0);
  constant off  : heat_ty := "00";
  constant low  : heat_ty := "01";
  constant high : heat_ty := "11";
end heat_pkg;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.heat_pkg.all;

entity heatingsys is                           -- finite state machine
  port(i_cur_temp       : in signed(7 downto 0); -- current temp
       i_des_temp       : in signed(7 downto 0); -- desired temp
       i_reset          : in std_logic;          -- reset
       i_clock          : in std_logic;          -- clock
       o_heatmode       : out heat_ty            -- mode
      );
end heatingsys;

architecture main of heatingsys is
  signal state  : heat_ty;
  signal temp_diff  : signed(7 downto 0);
begin

  temp_diff <= i_des_temp - i_cur_temp;
  o_heatmode <= state;

  statemachine : process
  begin
    wait until rising_edge(i_clock);
    if i_reset = '1' then
      state <= off;
    else
      case state is
        when off =>
          if temp_diff >= 5 then
            state <= high;
          elsif temp_diff >= 3 then
            state <= low;
          else
            state <= off;
          end if;

        when low =>
          if temp_diff >= 7 then
            state <= high;
          elsif temp_diff >= 2 then
            state <= low;
          else
            state <= off;
          end if;

        when high =>
          state <= off;
          if temp_diff >= 3 then
            state <= high;
          else
            state <= low;
          end if;

        -- Invalid state should go to off for safety
        when others =>
          state <= off;
      end case;
    end if;
  end process;
end main;

-- question 1
  -- The total number of basic elements in our design is as follows:
  -- 13 NOT gates
  -- 9 AND gates
  -- 13 OR gates
  -- 2 1-bit flip-flops (which is actually just one 2-bit flip-flop)
  -- 1 subtractor
