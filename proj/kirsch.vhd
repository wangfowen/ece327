library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package state_pkg is
  subtype state_ty is std_logic_vector(2 downto 0);
  constant S0 : state_ty := "001";

  subtype stage_state_ty is std_logic_vector(3 downto 0);

  subtype mem_data is unsigned(7 downto 0);
  type mem_data_vector is array(2 downto 0) of mem_data;
  type mem_data_crazy_vector is array(natural range <>) of mem_data_vector;
  
  --subtype wren_data is unsigned(3 downto 0);
  --type wren_data_vector is array(natural range <>) of wren_data;
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
  signal counter                  : unsigned(16 downto 0); -- 9 MSB is the row count, 8 LSB is the column count
  signal col_addr                 : mem_data_vector; -- done (hold i-2, i-1, i)
  signal stage1_valid             : stage_state_ty; -- todo
  signal stage2_valid             : stage_state_ty; -- todo
  
  signal mem_rd                   : mem_data_crazy_vector(2 downto 0);
  --signal wren_mem                 : wren_data_vector(2 downto 0);

  signal i_valid_and_mem_row_index    : state_ty;
  signal mem_row_index                : state_ty;


  signal mode                     : mode_ty;
  signal goto_init                : std_logic;
  signal row_count                : unsigned(7 downto 0);

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

  --restart when reset is pressed or reaches end of image
  goto_init <= '1' when i_reset = '1' or counter(16) = '1' else
               '0';

  SET_WREN : for I in 0 to 2 generate
    i_valid_and_mem_row_index(I) <= i_valid and mem_row_index(I);
  end generate SET_WREN;

  MEM_REDUN : for J in 0 to 2 generate
    MEM_CPY : for I in 0 to 2 generate
      mem : entity work.mem(main)
      port map (
        address => std_logic_vector(col_addr(J)),
        clock => i_clock,
        data => i_pixel,
        wren => i_valid_and_mem_row_index(I),
        unsigned(q) => mem_rd(I)(J) -- row/col, note: col is actually a separate mem block
      );
    end generate MEM_CPY;
  end generate MEM_REDUN;

  -- add dir mem

  increment_counters : process
  begin
    wait until rising_edge(i_clock);
    if (goto_init = '1') then
      counter <= to_unsigned(0, 17);
    elsif (i_valid = '1') then
      counter <= counter + 1;
    end if;
  end process;

  rotate_mem_row_index : process
  begin
    wait until rising_edge(i_clock);
    if (goto_init = '1') then
      mem_row_index <= S0;
    -- reached end of column
    elsif (i_valid = '1' and counter(7 downto 0) = 255) then
      mem_row_index <= mem_row_index rol 1;
    end if;
  end process;

  col_addr(2) <= counter(7 downto 0);
  col_last_three_counters : process
  begin
    wait until rising_edge(i_clock);
    if (goto_init = '1') then
      col_addr(0) <= to_unsigned(0, 8);
      col_addr(1) <= to_unsigned(0, 8);
    elsif (i_valid = '1') then
      col_addr(0) <= col_addr(1);
      col_addr(1) <= col_addr(2);
    end if;
  end process;

  set_mode : process
  begin
    wait until rising_edge(i_clock);
    if (goto_init = '1') then
      mode <= reset;
    end if;
    --TOOD: when set mode to busy? idle?
  end process;

  detect_edge_stage_1 : process
  begin
    wait until rising_edge(i_clock);
    if (goto_init = '1') then

    elsif (i_valid = '1' and counter(7 downto 0) > 3 and counter(16 downto 8) > 3) then -- Once we reach row 3 column 3, start doing convolution table stuff

    end if;
  end process;

  --TODO: how pipeline so this happens at end of other stages..?
  detect_edge_last_stage : process
  begin
    wait until rising_edge(i_clock);
    o_valid <= '1';
    --o_row <= std_logic_vector(row_count);
    --TODO: output correct things
    o_edge <= '0';
    o_dir <= "000";

    if (goto_init = '1' or row_count = 255) then
      row_count <= to_unsigned(0, 8);
    else
      row_count <= row_count + 1;
    end if;
  end process;

  o_mode <= mode;

  o_row <= std_logic_vector(col_addr(0));
end architecture;
