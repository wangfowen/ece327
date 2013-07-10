library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package state_pkg is
  subtype state_ty is std_logic_vector(2 downto 0);
  constant S0 : state_ty := "001";

  subtype stage_state_ty is std_logic_vector(3 downto 0);
  constant SS0 : stage_state_ty := "0000";

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
  signal i_valid_and_mem_row_index    : state_ty;
  signal mem_row_index                : state_ty;

  signal conv_vars                  : mem_data_crazy_vector;
  signal rd_c, rd_d                 : unsigned (7 downto 0);

  signal a1, b1, c1,
         h1,     d1,
         g1, f1, e1,
         a2, b2, c2,
         h2,     d2,
         g2, f2, e2                 : unsigned(7 downto 0);

  
  signal r1_s1                  : unsigned (9 downto 0);
  signal r2_s1                  : unsigned (9 downto 0);    
  signal sum1_src1_s1           : unsigned (9 downto 0);
  signal sum1_src2_s1           : unsigned (9 downto 0);
  signal sum1_s1                : unsigned (9 downto 0);
  signal sum2_src1_s1           : unsigned (9 downto 0);
  signal sum2_src2_s1           : unsigned (9 downto 0);
  signal sum2_s1                : unsigned (9 downto 0);

  signal mode                     : mode_ty;

  signal goto_init                : std_logic;
  signal valid_parcel1            : std_logic;
  signal valid_parcel2            : std_logic;
  
  signal row_count                : unsigned(7 downto 0);

   -- A function to rotate left (rol) a vector by n bits
  function "rol" ( a : std_logic_vector; n : natural )
  return std_logic_vector
  is
  begin
    return std_logic_vector( unsigned(a) rol n );
  end function;

  function "sll" ( a : std_logic_vector; n : natural )
  return std_logic_vector
  is
  begin
    return std_logic_vector( unsigned(a) sll n );
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
  -- TODO: counter bit is insuficient, we need to reset only when we sent the very last parcel
  -- ie. we need to wait 8 clock cycles after the last parcel (counter(16) = '1')
  goto_init <= '1' when i_reset = '1' else --or (counter(16) = '1') else
               '0';

  MEM_CPY : for I in 0 to 2 generate
    i_valid_and_mem_row_index(I) <= i_valid and mem_row_index(I);
    mem : entity work.mem(main)
    port map (
      address => std_logic_vector(counter(7 downto 0)),
      clock => i_clock,
      data => i_pixel,
      wren => i_valid_and_mem_row_index(I),
      unsigned(q) => mem_rd(I)
    );
  end generate MEM_CPY;

  -- todo: Replace this mux with tristate if possible
  rd_c <= (mem_rd(0) and (7 downto 0 => mem_row_index(2)))
    or (mem_rd(2) and (7 downto 0 => mem_row_index(1)))
    or (mem_rd(1) and (7 downto 0 => mem_row_index(0)));

  rd_d <= (mem_rd(1) and (7 downto 0 => mem_row_index(2)))
    or (mem_rd(0) and (7 downto 0 => mem_row_index(1)))
    or (mem_rd(2) and (7 downto 0 => mem_row_index(0)));

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
    elsif (i_valid = '1' and counter(7 downto 0) = 255) then -- reached end of column
      mem_row_index <= mem_row_index rol 1;
    end if;
  end process;

  latest_mem_rep_j : for J in 0 to 2 generate
    latest_mem_rep_i : for I in 0 to 2 generate
      latest_mem: process
      begin
        wait until rising_edge(i_clock);
        if (goto_init = '1') then
          conv_vars(J)(I) <= to_unsigned(0, 8);
        elsif (stage1_v(3) = '1') then
          conv_vars(J)(I) <= conv_vars(J+1)(I);
        end if;
      end process;
    end generate latest_mem_rep_i;
  end generate latest_mem_rep_j;

  latest_col: process
  begin
    wait until rising_edge(i_clock);
    if (goto_init = '1') then
      conv_vars(3)(0) <= to_unsigned(0, 8);
      conv_vars(3)(1) <= to_unsigned(0, 8);
      conv_vars(3)(2) <= to_unsigned(0, 8);
    elsif (i_valid = '1') then
      conv_vars(3)(0) <= rd_c;
      conv_vars(3)(1) <= rd_d;
      conv_vars(3)(2) <= unsigned(i_pixel);
    end if;
  end process;
  
  stage_1_v_bits : process
  begin
    wait until rising_edge(i_clock);
    stage1_v <= stage1_v sll 1;
    if (goto_init = '1') then
      stage1_v <= SS0;
    elsif (i_valid = '1') then
      stage1_v(0) <= '1';
    end if;
  end process;

  stage_2_v_bits : process
  begin
    wait until rising_edge(i_clock);
    stage2_v <= stage2_v sll 1;
    if (goto_init = '1') then
      stage2_v <= SS0;
    elsif (stage1_v(3) = '1') then
      stage2_v(0) <= '1';
    end if;
  end process;

  detect_edge_stage_1 : process
  begin
    wait until rising_edge(i_clock);
    if (goto_init = '1') then
      valid_parcel1 <= '0';
      o_dir <= "000"; --todo remove
    elsif (i_valid = '1') then
      if (counter(7 downto 0) >= 2 and counter(15 downto 8) >= 2) then -- Once we reach row 3 column 3, start triggering o_valid
        valid_parcel1 <= '1';
        o_dir <= "111"; -- todo remove
      else
        valid_parcel1 <= '0';
      end if;
    else
      valid_parcel1 <= valid_parcel1;
    end if;
  end process;

  carry_over_valid : process
  begin
    wait until rising_edge(i_clock);
    if (goto_init = '1') then
      valid_parcel2 <= '0';
    elsif (stage1_v(3) = '1') then
      valid_parcel2 <= valid_parcel1;
    else 
      valid_parcel2 <= valid_parcel2;
    end if;
  end process;

  final_valid : process
  begin
    wait until rising_edge(i_clock);
    if (goto_init = '1' or stage2_v(3) = '0') then
      o_valid <= '0';
    else
      o_valid <= valid_parcel2;
    end if;
  end process;

  a1 <= conv_vars(1)(0); b1 <= conv_vars(2)(0); c1 <= conv_vars(3)(0);
  h1 <= conv_vars(1)(1);                        d1 <= conv_vars(3)(1);
  g1 <= conv_vars(1)(2); f1 <= conv_vars(2)(2); e1 <= conv_vars(3)(2);
  
  a2 <= conv_vars(0)(0); b2 <= conv_vars(1)(0); c2 <= conv_vars(2)(0);
  h2 <= conv_vars(0)(1);                        d2 <= conv_vars(2)(1);
  g2 <= conv_vars(0)(2); f2 <= conv_vars(1)(2); e2 <= conv_vars(2)(2);

--------------------- STAGE1 ------------------------
  stage1_logic : process
  begin
    wait until rising_edge(i_clock);
    if (goto_init = '1') then
      r1_s1 <= to_unsigned(0, 10);
    
    elsif (i_valid = '1') then

    elsif (stage1_v(0) = '1') then
      r1_s1 <= sum1_s1;
    elsif (stage1_v(1) = '1') then
    
    elsif (stage1_v(2) = '1') then
   
    end if;
  end process;

-- Todo: replace with tri-state
  sum1_src1_s1 <=  "00" & h1 when stage1_v(0) = '1' else
                "00" & d1 when stage1_v(1) = '1' else
                r1_s1;

  sum1_s1 <= sum1_src1_s1 + sum1_src2_s1;
  sum2_s1 <= sum2_src1_s1 + sum2_src2_s1;

--------------------- STAGE2 ------------------------
 











--------------------- END ------------------------

  -- Stephane: code below, wut? 
 
  --TODO: how pipeline so this happens at end of other stages..?
  detect_edge_last_stage : process
  begin
    wait until rising_edge(i_clock);
    --o_row <= std_logic_vector(row_count);
    --TODO: output correct things

    if (goto_init = '1' or row_count = 255) then
      row_count <= to_unsigned(0, 8);
    else
      row_count <= row_count + 1;
    end if;
  end process;

--  set_mode : process
--  begin
--    wait until rising_edge(i_clock);
--    if (goto_init = '1') then
--      mode <= reset;
--    end if;
--    --TOOD: when set mode to busy? idle?
--  end process;
  
  o_mode <= mode;

  -- For debugging
  o_edge <= '1' when counter(8) = '1' else '0';
  --o_row <= std_logic_vector(counter(7 downto 0));
  o_row <= std_logic_vector(conv_vars(0)(2));
end architecture;
