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
  type mem_data_crazy_vector is array(2 downto 0) of mem_data_vector;
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
  signal stage1_v             : stage_state_ty;
  signal stage2_v             : stage_state_ty;

  --latest val in the 3 rows
  signal mem_rd                   : mem_data_vector;
  signal i_valid_and_mem_row_index    : state_ty;
  signal mem_row_index                : state_ty;

  --3x3 conv table
  signal conv_vars                  : mem_data_crazy_vector;
  signal rd_c, rd_d                 : unsigned (7 downto 0);

  signal a, b, c,
         h,    d,
         g, f, e                 : unsigned(7 downto 0);

--------------------- STAGE1 ------------------------
  signal r1                  : unsigned (8 downto 0);
  signal r2                  : unsigned (8 downto 0);
  signal r3                  : unsigned (8 downto 0);
  signal r4                  : unsigned (9 downto 0);
  signal r5                  : unsigned (9 downto 0);
  signal r6                  : unsigned (9 downto 0);
  signal r7                  : unsigned (7 downto 0);
  signal r14                 : unsigned (7 downto 0);
  signal r15                 : unsigned (7 downto 0);

  signal GE1                 : std_logic;
  signal sub1_src1           : unsigned (7 downto 0);
  signal sub1_src2           : unsigned (7 downto 0);
  signal sum1_src1           : unsigned (8 downto 0);
  signal sum1_src2           : unsigned (8 downto 0);
  signal sum1                : unsigned (9 downto 0);
  signal sum2_src1           : unsigned (8 downto 0);
  signal sum2_src2           : unsigned (8 downto 0);
  signal sum2                : unsigned (9 downto 0);

  signal dir                : unsigned (4 downto 1);

--------------------- STAGE2 ------------------------
  signal r11                  : unsigned (12 downto 0);
  signal r12                  : unsigned (9 downto 0);
  signal r13                  : unsigned (9 downto 0);
  signal r13_in               : unsigned (9 downto 0);

  signal sum3_src1           : unsigned (12 downto 0);
  signal sum3_src2           : unsigned (11 downto 0);
  signal sum3                : unsigned (12 downto 0);
  signal sum4_src1           : unsigned (8 downto 0);
  signal sum4_src2           : unsigned (8 downto 0);
  signal sum4                : unsigned (9 downto 0);
  signal sum5_src1           : unsigned (8 downto 0);
  signal sum5_src2           : unsigned (8 downto 0);
  signal sum5                : unsigned (9 downto 0);
  signal sub2_src1            : unsigned (12 downto 0);
  signal sub2_src2            : unsigned (12 downto 0);
  signal sub2                 : signed (13 downto 0);
  signal sub3_src1            : unsigned (9 downto 0);
  signal sub3_src2            : unsigned (9 downto 0);
  signal sub3                 : signed(10 downto 0);

  signal dir7                : unsigned (2 downto 0);

--------------------- ENDVAR ------------------------

  signal last_pixel_stage2        : std_logic;
  signal last_pixel_end           : std_logic;
  
  signal o_valid_tmp             : std_logic;
  signal o_mode_tmp             : std_logic_vector(1 downto 0);

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

  --1st row's most recent value
  rd_c <= (mem_rd(0) and (7 downto 0 => mem_row_index(2)))
       or (mem_rd(2) and (7 downto 0 => mem_row_index(1)))
       or (mem_rd(1) and (7 downto 0 => mem_row_index(0)));

  --2nd row's most recent value
  rd_d <= (mem_rd(1) and (7 downto 0 => mem_row_index(2)))
       or (mem_rd(0) and (7 downto 0 => mem_row_index(1)))
       or (mem_rd(2) and (7 downto 0 => mem_row_index(0)));

  increment_counters : process begin
    wait until rising_edge(i_clock);
    if (i_reset = '1') then 
      counter <= to_unsigned(0, 17);
    elsif (i_valid = '1') then
      counter <= counter + 1;
    elsif (o_mode_tmp(0) = '0') then
      counter <= to_unsigned(0, 17);
    end if;
  end process;

  rotate_mem_row_index : process begin
    wait until rising_edge(i_clock);
    if (o_mode_tmp(0) = '0') then
      mem_row_index <= S0;
    elsif (i_valid = '1' and counter(7 downto 0) = 255) then -- reached end of column
      mem_row_index <= mem_row_index rol 1;
    end if;
  end process;

  --rotate the conv table for the different directions
  latest_mem_rep_i : for I in 0 to 2 generate
    latest_mem_rep_j : for J in 0 to 1 generate
      latest_mem: process begin
        wait until rising_edge(i_clock);
        if (i_valid = '1') then
          conv_vars(I)(J) <= conv_vars(I)(J + 1);
        end if;
      end process;
    end generate latest_mem_rep_j;
  end generate latest_mem_rep_i;

  --update the conv table with the new values
  latest_col: process begin
    wait until rising_edge(i_clock);
    if (i_valid = '1') then
      conv_vars(0)(2) <= rd_c;
      conv_vars(1)(2) <= rd_d;
      conv_vars(2)(2) <= unsigned(i_pixel);
    end if;
  end process;

  v_bits : process
  begin
    wait until rising_edge(i_clock);
    stage1_v <= stage1_v sll 1;
    stage2_v <= stage2_v sll 1;
    if (i_reset = '1') then
      stage2_v <= SS0;
    elsif (i_valid = '1' and counter(7 downto 1) >= 1 and counter(15 downto 9) >= 1) then
      stage1_v(0) <= '1';
    end if;
    if (i_reset = '1') then
      stage2_v <= SS0;
    elsif (stage1_v(3) = '1') then
      stage2_v(0) <= '1';
    end if;
  end process;

  o_valid_carry_through : process begin
    wait until rising_edge(i_clock);
    o_valid_tmp <= stage2_v(3); -- at last part of stage 2, output validity

    if (stage1_v(3) = '1') then
      last_pixel_stage2 <= counter(16);
    end if;
    if (stage2_v(3) = '1') then
      last_pixel_end <= last_pixel_stage2;
    end if;
  end process;
  o_valid <= o_valid_tmp;

  a <= conv_vars(0)(0); b <= conv_vars(0)(1); c <= conv_vars(0)(2);
  h <= conv_vars(1)(0);                       d <= conv_vars(1)(2);
  g <= conv_vars(2)(0); f <= conv_vars(2)(1); e <= conv_vars(2)(2);

--------------------- STAGE1 ------------------------

  all_first_stage_dirs : for I in 1 to 4 generate
    dir_proc: process begin
      wait until rising_edge(i_clock);
      if (stage1_v(I-1) = '1') then
        dir(I) <= GE1;
      end if;
    end process;
  end generate all_first_stage_dirs;

  R1_R2_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(0) = '1') then
      r1 <= sum1(8 downto 0);
      r2 <= sum2(8 downto 0);
    elsif (stage1_v(3) = '1') then
      r2(7 downto 0) <= r7;
    end if;
  end process;

  R3_R4_proc : process begin
    wait until rising_edge(i_clock);
    
    if (stage1_v(2) = '1') then
      r3 <= r5(8 downto 0);
    elsif (stage2_v(0) = '1') then
      if (sub3(10) = '0') then
        r3(2 downto 0) <= dir(1) & '0' & not(dir(1));
      else
        r3(2 downto 0) <= dir(2) & "10";
      end if;
    elsif (stage2_v(1) = '1') then
      if (sub3(10) = '0') then
        r3(5 downto 3) <= dir(3) & '0' & dir(3);
      else
        r3(5 downto 3) <= dir(4) & "11";
      end if;
    end if;

    if (stage1_v(1) = '1') then
      r4(7 downto 0) <= r7;
    elsif (stage1_v(2) = '1') then
      r4 <= r6;
    elsif (stage2_v(0) = '1') then
      if (sub3(10) = '0') then
        r4 <= r12;
      else
        r4 <= r13;
      end if;
    end if;
  end process;

  R5_R6_proc : process begin
    wait until rising_edge(i_clock);
    r5 <= sum1;
    r6 <= sum2;
  end process;

  R14_R15_proc: process begin
    wait until rising_edge(i_clock);
    if (i_valid = '1') then
      r14 <= f; -- g (prev value)
      r15 <= c; -- b (prev value)
    elsif (stage1_v(0) = '1') then
      r14 <= a;
      r15 <= d;
    elsif (stage1_v(1) = '1') then
      r14 <= c;
      r15 <= f;
    else
      r14 <= e;
      r15 <= h;
    end if;
  end process;

  R7_proc : process begin
    wait until rising_edge(i_clock);
    if (GE1 = '0') then
      r7 <= r14;
    else
      r7 <= r15;
    end if;
  end process;

  sum1_src1 <= '0' & h when stage1_v(0) = '1' else
               '0' & d when stage1_v(1) = '1' else
               r1;
  sum1_src2 <= '0' & a when stage1_v(0) = '1' else
               '0' & e when stage1_v(1) = '1' else
               '0' & r4(7 downto 0) when stage1_v(2) = '1' else
               r2;

  sum2_src1 <= '0' & b when stage1_v(0) = '1' else
               '0' & f when stage1_v(1) = '1' else
               r2 when stage1_v(2) = '1' else
               r3;
  sum2_src2 <= '0' & c when stage1_v(0) = '1' else
               '0' & g when stage1_v(1) = '1' else
               '0' & r7 when stage1_v(2) = '1' else
               r4(8 downto 0);
  
  sum1 <= ('0' & sum1_src1) + ('0' & sum1_src2);
  sum2 <= ('0' & sum2_src1) + ('0' & sum2_src2);

  sub1_src1 <= r14;
  sub1_src2 <= r15;
  GE1 <= '0' when sub1_src1 >= sub1_src2 else '1';

--------------------- STAGE2 ------------------------

  dirs_proc: process begin
    wait until rising_edge(i_clock);
    if (stage2_v(2) = '1') then
      if (sub3(10) = '0') then
        dir7 <= r3(2 downto 0); -- old dir5
      else
        dir7 <= r3(5 downto 3); -- old dir6
      end if;
    end if;
  end process;

  r11_proc : process begin
    wait until rising_edge(i_clock);
    r11 <= sum3;
  end process;

  r12_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(3) = '1') then
      r12 <= r5;
    elsif (stage2_v(0) = '1') then
      r12 <= sum4;
    else
      r12 <= r4;
    end if;
  end process;

  r13_proc : process begin
    wait until rising_edge(i_clock);
    r13 <= r13_in;
  end process;
  r13_in <= (r6 and (9 downto 0 => stage1_v(3)))
       or (sum5 and (9 downto 0 => not stage1_v(3) and not stage2_v(1) and not stage2_v(2)))
        or (r12 and (9 downto 0 => not stage1_v(3) and not stage2_v(0) and not sub3(10)))
        or (r13 and (9 downto 0 => not stage1_v(3) and not stage2_v(0) and sub3(10)));

  sum3_src1 <= "000" & r5 when stage2_v(0) = '1' else
               r11;
  sum3_src2 <= "00" & r6 when stage2_v(0) = '1' else
               (r11(11 downto 0) sll 1) when stage2_v(1) = '1' else
               to_unsigned(384, 12);
  sum4_src1 <= r3;
  sum4_src2 <= '0' & r2(7 downto 0);
  sum5_src1 <= r4(8 downto 0);
  sum5_src2 <= '0' & r7;
  sum3 <= (      sum3_src1) + ('0' & sum3_src2);
  sum4 <= ('0' & sum4_src1) + ('0' & sum4_src2);
  sum5 <= ('0' & sum5_src1) + ('0' & sum5_src2);

  sub2_src1 <= ("000" & r13) sll 3;
  sub2_src2 <= r11;
  sub3_src1 <= r12;
  sub3_src2 <= r13;
  sub2 <= signed('0' & sub2_src1) - signed('0' & sub2_src2);
  sub3 <= signed('0' & sub3_src1) - signed('0' & sub3_src2);

--------------------- END ------------------------

  o_edge_proc1: process begin
    wait until rising_edge(i_clock);
    o_edge <= not(sub2(13));
    if (sub2(13) = '1') then
      o_dir <= "000";
    else
      o_dir <= std_logic_vector(dir7);
    end if;
  end process;

  o_row_proc : process begin
    wait until rising_edge(i_clock);
    if (i_reset = '1') then
      o_row <= "00000000";
    elsif (i_valid = '1') then
      o_row <= std_logic_vector(counter(15 downto 8));
    end if;
  end process;

  o_mode_proc : process begin
    wait until rising_edge(i_clock);
    o_mode_tmp(1) <= not(i_reset);
    if (i_reset = '1' or i_valid = '1') then
      o_mode_tmp(0) <= '1';
    elsif (o_mode_tmp(1) = '0') then
      o_mode_tmp(0) <= '0';
    elsif (o_valid_tmp = '1') then
      o_mode_tmp(0) <= not(last_pixel_end);
    end if;
  end process;
  o_mode(0) <= o_mode_tmp(0);
  o_mode(1) <= o_mode_tmp(1);

  -- For debugging
  -- debug_num_0 <= std_logic_vector(sub2(3 downto 0));
  -- debug_num_1 <= std_logic_vector(sub2(7 downto 4));
  -- debug_num_2 <= std_logic_vector(sub2(11 downto 8));
  -- debug_num_3 <= std_logic_vector("00" & sub2(13 downto 12));
  -- debug_num_4 <= std_logic_vector('0' & dir7);
  -- debug_num_5 <= counter(16) & counter(0) & '0' & '0';
end architecture;
