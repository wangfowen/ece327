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
  signal stage1_v             : stage_state_ty; -- todo
  signal stage2_v             : stage_state_ty; -- todo

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
  signal r4                  : unsigned (8 downto 0);
  signal r5                  : unsigned (9 downto 0);
  signal r6                  : unsigned (9 downto 0);
  signal r7                  : unsigned (7 downto 0);
  signal r8                  : unsigned (7 downto 0);
  signal r9                  : unsigned (7 downto 0);
  signal r10                 : unsigned (7 downto 0);

  signal sub1_src1            : unsigned (7 downto 0);
  signal sub1_src2            : unsigned (7 downto 0);
  signal sub1                 : signed (8 downto 0);
  signal sum1_src1           : unsigned (8 downto 0);
  signal sum1_src2           : unsigned (8 downto 0);
  signal sum1                : unsigned (9 downto 0);
  signal sum2_src1           : unsigned (8 downto 0);
  signal sum2_src2           : unsigned (8 downto 0);
  signal sum2                : unsigned (9 downto 0);

  signal dir1                : unsigned (2 downto 0);
  signal dir2                : unsigned (2 downto 0);
  signal dir3                : unsigned (2 downto 0);
  signal dir4                : unsigned (2 downto 0);

--------------------- STAGE2 ------------------------
  signal r11                  : unsigned (12 downto 0);
  signal r12                  : unsigned (12 downto 0);
  signal r13                  : unsigned (12 downto 0);
  signal r14                  : unsigned (9 downto 0);

  signal sum3_src1           : unsigned (12 downto 0);
  signal sum3_src2           : unsigned (12 downto 0);
  signal sum3                : unsigned (12 downto 0);
  signal sum4_src1           : unsigned (9 downto 0);
  signal sum4_src2           : unsigned (9 downto 0);
  signal sum4                : unsigned (9 downto 0);
  signal sub2_src1            : unsigned (9 downto 0);
  signal sub2_src2            : unsigned (9 downto 0);
  signal sub2                 : signed (9 downto 0);
  signal sub3_src1            : unsigned (12 downto 0);
  signal sub3_src2            : unsigned (12 downto 0);
  signal sub3                 : signed (12 downto 0);

--------------------- ENDVAR ------------------------

  signal valid_parcel1            : std_logic;
  signal valid_parcel2            : std_logic;
  signal goto_init                : std_logic;

  signal mode                     : mode_ty;

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
  --next row's most recent value
  rd_c <= (mem_rd(0) and (7 downto 0 => mem_row_index(2)))
    or (mem_rd(2) and (7 downto 0 => mem_row_index(1)))
    or (mem_rd(1) and (7 downto 0 => mem_row_index(0)));

  --prev row's most recent value
  rd_d <= (mem_rd(1) and (7 downto 0 => mem_row_index(2)))
    or (mem_rd(0) and (7 downto 0 => mem_row_index(1)))
    or (mem_rd(2) and (7 downto 0 => mem_row_index(0)));

  increment_counters : process begin
    wait until rising_edge(i_clock);
    if (goto_init = '1') then
      counter <= to_unsigned(0, 17);
    elsif (i_valid = '1') then
      counter <= counter + 1;
    end if;
  end process;

  rotate_mem_row_index : process begin
    wait until rising_edge(i_clock);
    if (goto_init = '1') then
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
        if (goto_init = '1') then
          conv_vars(I)(J) <= to_unsigned(0, 8);
        elsif (i_valid = '1') then
          conv_vars(I)(J) <= conv_vars(I)(J + 1);
        end if;
      end process;
    end generate latest_mem_rep_j;
  end generate latest_mem_rep_i;

  --update the conv table with the new values
  latest_col: process begin
    wait until rising_edge(i_clock);
    if (goto_init = '1') then
      conv_vars(0)(2) <= to_unsigned(0, 8);
      conv_vars(1)(2) <= to_unsigned(0, 8);
      conv_vars(2)(2) <= to_unsigned(0, 8);
    elsif (i_valid = '1') then
      conv_vars(0)(2) <= rd_c;
      conv_vars(1)(2) <= rd_d;
      conv_vars(2)(2) <= unsigned(i_pixel);
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

  -- if within the inner part, is valid to output
  detect_edge_stage_1 : process begin
    wait until rising_edge(i_clock);
    if (i_valid = '1') then
      if (counter(7 downto 0) >= 2 and counter(15 downto 8) >= 2) then -- Once we reach row 3 column 3, start triggering o_valid
        valid_parcel1 <= '1';
        o_dir <= "111"; -- todo remove
      else
        valid_parcel1 <= '0';
      end if;
    end if;
  end process;

  -- at the last part of stage 1, pass to stage 2
  carry_over_valid : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(3) = '1') then
      valid_parcel2 <= valid_parcel1;
    end if;
  end process;

  -- at last part of stage 2, output validity
  final_valid : process begin
    wait until rising_edge(i_clock);
    if (goto_init = '1' or stage2_v(3) = '0') then
      o_valid <= '0';
    else
      o_valid <= valid_parcel2;
    end if;
  end process;

  a <= conv_vars(0)(0); b <= conv_vars(0)(1); c <= conv_vars(0)(2);
  h <= conv_vars(1)(0);                       d <= conv_vars(1)(2);
  g <= conv_vars(2)(0); f <= conv_vars(2)(1); e <= conv_vars(2)(2);

--------------------- STAGE1 ------------------------

  R1_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(0) = '1') then
      r1 <= sum1(8 downto 0);
    end if;
  end process;

  R2_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(0) = '1') then
      r2 <= sum2(8 downto 0);
    end if;
  end process;

  R3_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(2) = '1') then
      r3 <= r5(8 downto 0);
    end if;
  end process;

  R4_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(2) = '1') then
      r4 <= r6(8 downto 0);
    end if;
  end process;

  R5_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(1) = '1' or stage1_v(2) = '1') then
      r5 <= sum1;
    end if;
  end process;

  R6_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(1) = '1' or stage1_v(2) = '1') then
      r6 <= sum2;
    end if;
  end process;

  R7_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(0) = '1') then
      if (sub1(8) = '1') then
        dir1 <= "100";
        r7 <= b;
      else
        dir1 <= "001";
        r7 <= g;
      end if;
    end if;
  end process;

  R8_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(1) = '1') then
      if (sub1(8) = '1') then
        dir2 <= "110";
        r8 <= d;
      else
        dir2 <= "010";
        r8 <= a;
      end if;
    end if;
  end process;

  R9_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(2) = '1') then
      if (sub1(8) = '1') then
        dir3 <= "101";
        r9 <= f;
      else
        dir3 <= "000";
        r9 <= c;
      end if;
    end if;
  end process;

  R10_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(3) = '1') then
      if (sub1(8) = '1') then
        dir4 <= "111";
        r10 <= h;
      else
        dir4 <= "011";
        r10 <= e;
      end if;
    end if;
  end process;

-- Todo: replace dis shit with tri-state
  sum1_src1 <= '0' & h when stage1_v(0) = '1' else
                  '0' & d when stage1_v(1) = '1' else
                  r1;
  sum1_src2 <= '0' & a when stage1_v(0) = '1' else
                  '0' & e when stage1_v(1) = '1' else
                  '0' & r7 when stage1_v(2) = '1' else
                  r2 when stage1_v(3) = '1';
  sum2_src1 <= '0' & b when stage1_v(0) = '1' else
                  '0' & f when stage1_v(1) = '1' else
                  r1 when stage1_v(2) = '1' else
                  r3 when stage1_v(3) = '1';
  sum2_src2 <= '0' & c when stage1_v(0) = '1' else
                  '0' & g when stage1_v(1) = '1' else
                  '0' & r8 when stage1_v(2) = '1' else
                  r4 when stage1_v(3) = '1';

  sub1_src1 <=  g when stage1_v(0) = '1' else
                  a when stage1_v(1) = '1' else
                  c when stage1_v(2) = '1' else
                  e when stage1_v(3) = '1';
  sub1_src2 <=  b when stage1_v(0) = '1' else
                  d when stage1_v(1) = '1' else
                  f when stage1_v(2) = '1' else
                  h when stage1_v(3) = '1';

  -- todo: maybe use a GE instead of sub. Will need to test.
  sub1 <= signed('0' & sub1_src1) - signed('0' & sub1_src2);
  sum1 <= ('0' & sum1_src1) + ('0' & sum1_src2);
  sum2 <= ('0' & sum2_src1) + ('0' & sum2_src2);

--------------------- STAGE2 ------------------------

  -- alright dude, here are a few pointers:
  -- 1. Check DFD_Real in ece327 google drive folder
  -- 2. Re-use registers R10, R4, R9, R5, R6 for ONLy the first clock cycle of S2
  -- 3. Put in new registers in DFD real doc for stage 2
  -- 4. Look at my code for stage 1 as an example
  -- 5. Instead of a "max" block, use what I did for R7,8,9,10.
  -- 6. dir5 = max(max1, max2) will choose dir1 or dir2 respectively. dir6 is the same on max3/max4 for dir3,4
  -------- THat's why we saved dir1, dir2, dir3, dir4, and that is the insight behind my discovery. ORDER is preserved!
  -- 7. dir7 = max(max5, max6) will choose between dir5 and dir6
  -- 8. Be smart about how you choose your registers... MINIMIZE muxes

  r11_proc : process begin
    wait until rising_edge(i_clock);
    r11 <= sum3;
  end process;

  r12_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(3) = '1') then
      r12 <= "000" & r6;
    elsif (stage2_v(0) = '1') then
      r12 <= "000" & sum4;
    elsif (sub2(9) = '0') then
      r12 <= r13;
    end if;
  end process;

  r13_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(3) = '1') then
      r13 <= "000" & r5;
    elsif (stage2_v(0) = '1') then
      r13 <= sum3;
    elsif (stage2_v(1) = '1') then
      r13 <= "000" & r14;
    elsif (stage2_v(2) = '1') then
      if (sub2(9) = '0') then
        r13 <= r13 sll 3;
      else
        r13 <= r12 sll 3;
      end if;
    end if;
  end process;

  r14_proc : process begin
    wait until rising_edge(i_clock);
    if (stage2_v(0) = '1') then
      if (sub2(9) = '0') then
        r14 <= r13(9 downto 0);
      else
        r14 <= r12(9 downto 0);
      end if;
    end if;
  end process;

  sum3_src1 <= "0000" & r3 when stage2_v(0) = '1' else
               "000" & r5 when stage2_v(1) = '1' else
               r11;
  sum3_src2 <= "00000" & r10 when stage2_v(0) = '1' else
               "000" & r6 when stage2_v(1) = '1' else
               r11 sll 1;
  sum4_src1 <= '0' & r4;
  sum4_src2 <= "00" & r9;

  sub2_src1 <= r13(9 downto 0);
  sub2_src2 <= r12(9 downto 0);
  sub3_src1 <= r13;
  sub3_src2 <= r11;

  -- todo: maybe use a GE instead of sub. Will need to test.
  sub2 <= signed(sub2_src1) - signed(sub2_src2);
  sub3 <= signed(sub3_src1) - signed(sub3_src2);
  sum3 <= (sum3_src1) + (sum3_src2);
  sum4 <= (sum4_src1) + (sum4_src2);

--------------------- END ------------------------

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
  o_row <= std_logic_vector(sum1(7 downto 0));
end architecture;
