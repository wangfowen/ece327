library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package state_pkg is
  subtype state_ty is std_logic_vector(2 downto 0);
  constant S0 : state_ty := "001";
  constant S1 : state_ty := "010";
  constant S2 : state_ty := "100";

  subtype mem_data is unsigned(7 downto 0);
  type mem_data_vector is array(natural range <>) of mem_data;
end state_pkg;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.state_pkg.all;
use work.kirsch_synth_pkg.all;

entity kirsch is
  port(
    ------------------------------------------
    -- main inputs and outputs
    i_clock    : in  std_logic;
    i_reset    : in  std_logic;
    i_valid    : in  std_logic;
    i_pixel    : in  std_logic_vector(7 downto 0);
    o_valid    : out std_logic;
    o_edge     : out std_logic;
    o_dir      : out std_logic_vector(2 downto 0);
    o_mode     : out std_logic_vector(1 downto 0);
    o_row      : out std_logic_vector(7 downto 0);
    ------------------------------------------
    -- debugging inputs and outputs
    debug_key      : in  std_logic_vector( 3 downto 1) ;
    debug_switch   : in  std_logic_vector(17 downto 0) ;
    debug_led_red  : out std_logic_vector(17 downto 0) ;
    debug_led_grn  : out std_logic_vector(5  downto 0) ;
    debug_num_0    : out std_logic_vector(3 downto 0) ;
    debug_num_1    : out std_logic_vector(3 downto 0) ;
    debug_num_2    : out std_logic_vector(3 downto 0) ;
    debug_num_3    : out std_logic_vector(3 downto 0) ;
    debug_num_4    : out std_logic_vector(3 downto 0) ;
    debug_num_5    : out std_logic_vector(3 downto 0)
    ------------------------------------------
  );
end entity;


architecture main of kirsch is
  signal q                        : mem_data_vector(2 downto 0);
  signal row_index                : state_ty;
  signal i_valid_and_row_index    : state_ty;
  signal mode                     : mode_ty;
  signal goto_init                : std_logic;
  signal counter                  : unsigned(16 downto 0); -- 9 MSB is the row count, 8 LSB is the column count

   -- A function to rotate left (rol) a vector by n bits
  function "rol" ( a : std_logic_vector; n : natural )
  return std_logic_vector
  is
  begin
    return std_logic_vector( unsigned(a) rol n );
  end function;
begin

  debug_num_5 <= X"E";
  debug_num_4 <= X"C";
  debug_num_3 <= X"E";
  debug_num_2 <= X"3";
  debug_num_1 <= X"2";
  debug_num_0 <= X"7";

  debug_led_red <= (others => '0');
  debug_led_grn <= (others => '0');

  goto_init <= '1' when i_reset = '1' or counter(8) = '1' else
               '0';

  MEM_CPY : for I in 0 to 2 generate
    i_valid_and_row_index(I) <= i_valid and row_index(I);
    mem : entity work.mem(main)
    port map (
      address => std_logic_vector(counter(7 downto 0)), -- just column counter
      clock => i_clock,
      data => i_pixel,
      wren => i_valid_and_row_index(I),
      unsigned(q) => q(I)
    );
  end generate MEM_CPY;

  increment_counters : process
  begin
    wait until rising_edge(i_clock);
    if (goto_init = '1') then
      counter <= to_unsigned(0, 17);
    elsif (i_valid = '1') then
      counter <= counter + 1;
    end if;
  end process;

  rotate_row_index : process
  begin
    wait until rising_edge(i_clock);
    if (goto_init = '1') then
      row_index <= S0;
    -- reached end of column
    elsif (i_valid = '1' and counter(7 downto 0) = 255) then
      row_index <= row_index rol 1;
    end if;
  end process;


  set_mode : process
  begin
    wait until rising_edge(i_clock);
    if (goto_init = '1') then
      mode <= reset;
    end if;
  end process;

  --TODO: calculations on 3x3 convolution table, set mode to busy til done
  --TODO: when finish calculations set mode to idle then output correct things
  o_edge <= '0';
  o_dir <= "000";
  o_mode <= mode;
  o_row <= "00000000";
end architecture;
