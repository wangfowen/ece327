library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package state_pkg is
  subtype state_ty is std_logic_vector(2 downto 0);
  constant S0 : state_ty := "001";

  subtype stage_state_ty is std_logic_vector(3 downto 0);

  subtype mem_data is unsigned(7 downto 0);
  type mem_data_vector is array(2 downto 0) of mem_data;
  type mem_data_crazy_vector is array(3 downto 0) of mem_data_vector;
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
  signal stage1_v             : stage_state_ty; -- todo
  signal stage2_v             : stage_state_ty; -- todo
  
  signal mem_rd                   : mem_data_vector;

  --signal wr_data                  : mem_data_vector; -- done (hold last 2 values)
  --signal col_addr                 : mem_data_vector; -- done (hold i-2, i-1, i)

  signal i_valid_and_mem_row_index    : state_ty;
  signal mem_row_index                : state_ty;

  signal conv_vars                  : mem_data_crazy_vector;
  signal c1, d1                     : unsigned (7 downto 0);
  --signal a1, b1, c1,
  --       h1, i1, d1, 
  --       g1, f1, e1,
  --       a2,
  --       h2,
  --       g3                       : unsigned(7 downto 0);

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

  --SET_WREN : for I in 0 to 2 generate
  --end generate SET_WREN;

  --MEM_REDUN : for J in 0 to 2 generate
  MEM_CPY : for I in 0 to 2 generate
    i_valid_and_mem_row_index(I) <= i_valid and mem_row_index(I); 
    mem : entity work.mem(main)
    port map (
      address => std_logic_vector(counter(7 downto 0)),
      clock => i_clock,
      data => i_pixel,
      wren => i_valid_and_mem_row_index(I),
      unsigned(q) => mem_rd(I) --mem_rd(I)(J) 
    );
  end generate MEM_CPY;
  --end generate MEM_REDUN;

  -- todo: Replace this mux with tristate
  c1 <= (mem_rd(0) and (7 downto 0 => mem_row_index(2))) 
    or (mem_rd(2) and (7 downto 0 => mem_row_index(1))) 
    or (mem_rd(1) and (7 downto 0 => mem_row_index(0)));

  d1 <= (mem_rd(0) and (7 downto 0 => mem_row_index(2))) 
    or (mem_rd(2) and (7 downto 0 => mem_row_index(1))) 
    or (mem_rd(1) and (7 downto 0 => mem_row_index(0)));

  
  -- TODO: add dir mem. Idea is simple, we need the old version of the memory for second stage of pipeline

  increment_counters : process
  begin
    wait until rising_edge(i_clock);
    if (goto_init = '1') then
      counter <= to_unsigned(0, 17);
    elsif (i_valid = '1') then
      -- TODO: When valid bits are added, only increment once we reach S1 valid bit 3
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

  -- TODO: make for generate from 0 to 1
  --col_addr(2) <= counter(7 downto 0);
  -- <= unsigned(i_pixel);
  last_three_mem : process
  begin
    wait until rising_edge(i_clock);
    if (goto_init = '1') then
      
      --col_addr(0) <= to_unsigned(0, 8);
      --col_addr(1) <= to_unsigned(0, 8);

      --wr_data(0) <= to_unsigned(0, 8);
      --wr_data(1) <= to_unsigned(0, 8);
    elsif (i_valid = '1') then -- or valid bit 1 of stage 2

      conv_vars(3)(0) <= c1;
      conv_vars(3)(1) <= d1;
      conv_vars(3)(2) <= unsigned(i_pixel);

    elsif (i_valid = '0') then -- i_valid or stage 4

      conv_vars(2)(0) <= conv_vars(3)(0);
      conv_vars(2)(1) <= conv_vars(3)(1);
      conv_vars(2)(2) <= conv_vars(3)(2);
      
      conv_vars(1)(0) <= conv_vars(2)(0);
      conv_vars(1)(1) <= conv_vars(2)(1);
      conv_vars(1)(2) <= conv_vars(2)(2);

      conv_vars(0)(0) <= conv_vars(1)(0);
      conv_vars(0)(1) <= conv_vars(1)(1);
      conv_vars(0)(2) <= conv_vars(1)(2);


      --col_addr(0) <= col_addr(1);
      --col_addr(1) <= col_addr(2);

      --wr_data(0) <= wr_data(1);
      --wr_data(1) <= wr_data(2);
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
    o_dir <= "000";
    elsif (i_valid = '1' and counter(7 downto 0) >= 2 and counter(16 downto 8) >= 2) then -- Once we reach row 3 column 3, start doing convolution table stuff
      
    o_dir <= "111";
    end if;
  end process;

  --TODO: how pipeline so this happens at end of other stages..?
  detect_edge_last_stage : process
  begin
    wait until rising_edge(i_clock);
    o_valid <= '1';
    --o_row <= std_logic_vector(row_count);
    --TODO: output correct things

    if (goto_init = '1' or row_count = 255) then
      row_count <= to_unsigned(0, 8);
    else
      row_count <= row_count + 1;
    end if;
  end process;

  o_mode <= mode;
  
  -- For debugging
  o_edge <= '1' when counter(8) = '1' else '0';
  o_row <= std_logic_vector(counter(7 downto 0));
end architecture;
