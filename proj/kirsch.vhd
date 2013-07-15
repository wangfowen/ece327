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
  signal temp : signed(5 downto 0);
--------------------- STAGE1 ------------------------
  signal r1                  : unsigned (8 downto 0);
  signal r2                  : unsigned (8 downto 0);
  signal r3                  : unsigned (8 downto 0);
  signal r4                  : unsigned (8 downto 0);
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
  signal r17                  : unsigned (12 downto 0);
  signal r12                  : unsigned (9 downto 0);
  signal r13                  : unsigned (9 downto 0);
  signal r16                  : unsigned (12 downto 0);

  signal sum3_src1           : unsigned (11 downto 0);
  signal sum3_src2           : unsigned (11 downto 0);
  signal sum3                : unsigned (12 downto 0);
  signal sum6_src1           : unsigned (12 downto 0);
  signal sum6_src2           : unsigned (12 downto 0);
  signal sum6                : unsigned (12 downto 0);
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
 
  signal dir5                : unsigned (2 downto 0);
  signal dir6                : unsigned (2 downto 0);

--------------------- ENDVAR ------------------------

  signal valid_parcel1            : std_logic;
  signal valid_parcel2            : std_logic;
  signal goto_init                : std_logic;

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
  --debug_num_5 <= X"E";
  --debug_num_4 <= X"C";
  --debug_num_3 <= X"E";
  --debug_num_2 <= X"3";
  --debug_num_1 <= X"2";
  --debug_num_0 <= X"7";

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

  v_bits : process
  begin
    wait until rising_edge(i_clock);
    stage1_v <= stage1_v sll 1;
    stage2_v <= stage2_v sll 1;
    if (i_reset = '1') then
      stage1_v <= SS0;
    elsif (i_valid = '1') then
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
    
    -- if within the inner part, is valid to output
    if (i_valid = '1') then
      if (counter(7 downto 0) >= 2 and counter(15 downto 8) >= 2) then -- Once we reach row 3 column 3, start triggering o_valid
        valid_parcel1 <= '1';
      else
        valid_parcel1 <= '0';
      end if;
    end if;
    
    -- at the last part of stage 1, pass to stage 2
    if (stage1_v(3) = '1') then
      valid_parcel2 <= valid_parcel1;
    end if;
    
    -- at last part of stage 2, output validity
    if (stage2_v(2) = '0') then
      o_valid <= '0';
    else
      o_valid <= valid_parcel2;
    end if;
  end process;

  --o_valid <= '0' when goto_init = '1' or stage2_v(3) = '0' or valid_parcel2 = '0' else
  --           '1';

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
      r4 <= r6(8 downto 0);
    elsif (stage1_v(1) = '1') then
      r4(7 downto 0) <= r7;
    end if;
  end process;

  R5_R6_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(1) = '1' or stage1_v(2) = '1' or stage1_v(3) = '1') then
      r5 <= sum1;
      r6 <= sum2;
    end if;
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
    elsif (stage1_v(2) = '1') then
      r14 <= e;
      r15 <= h;
    end if;
  end process;

  R7_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(0) = '1' or stage1_v(1) = '1' or stage1_v(2) = '1' or stage1_v(3) = '1') then
      if (GE1 = '0') then
        r7 <= r14;
      else
        r7 <= r15;
      end if;
    end if;
  end process;
 
  sum1_src1 <= '0' & h when stage1_v(0) = '1' else
               '0' & d when stage1_v(1) = '1' else
               r1;
  --sum1_src2 <= '0' & a when stage1_v(0) = '1' else
  --             '0' & e when stage1_v(1) = '1' else
  --             '0' & r4(7 downto 0) when stage1_v(2) = '1' else
  --                   r2;
  --sum2_src1 <= '0' & b when stage1_v(0) = '1' else
  --             '0' & f when stage1_v(1) = '1' else
  --                  r2 when stage1_v(2) = '1' else
  --                  r3;
  --sum2_src2 <= '0' & c when stage1_v(0) = '1' else
  --             '0' & g when stage1_v(1) = '1' else
  --             '0' & r7 when stage1_v(2) = '1' else
  --                   r4;

  
  --sum1_src1 <= ('0' & (h and (7 downto 0 => stage1_v(0))))
  --          or ('0' & (d and (7 downto 0 => stage1_v(1))))
  --          or (r1 and (8 downto 0 => (stage1_v(2) or stage1_v(3))));
  sum1_src2 <= ('0' & (a and (7 downto 0 => stage1_v(0))))
            or ('0' & (e and (7 downto 0 => stage1_v(1))))
            or ('0' & (r4(7 downto 0) and (7 downto 0 => stage1_v(2))))
            or (r2 and (8 downto 0 => stage1_v(3)));
  
  sum2_src1 <= ('0' & (b and (7 downto 0 => stage1_v(0))))
            or ('0' & (f and (7 downto 0 => stage1_v(1))))
                  or (r2 and (8 downto 0 => stage1_v(2)))
                  or (r3 and (8 downto 0 => stage1_v(3)));
  sum2_src2 <= ('0' & (c and (7 downto 0 => stage1_v(0))))
            or ('0' & (g and (7 downto 0 => stage1_v(1))))
           or ('0' & (r7 and (7 downto 0 => stage1_v(2))))
                  or (r4 and (8 downto 0 => stage1_v(3)));

  sub1_src1 <= r14;
  sub1_src2 <= r15;

  GE1 <= '0' when sub1_src1 >= sub1_src2 else '1';
  sum1 <= ('0' & sum1_src1) + ('0' & sum1_src2);
  sum2 <= ('0' & sum2_src1) + ('0' & sum2_src2);

--------------------- STAGE2 ------------------------

  dirs_proc: process begin
    wait until rising_edge(i_clock);
    if (stage2_v(0) = '1') then
      if (sub3(10) = '0') then
        dir5 <= dir(1) & '0' & not(dir(1));
      else
        dir5 <= dir(2) & "10";
      end if;
    end if;
    
    if (stage2_v(1) = '1') then
      if (sub3(10) = '0') then
        dir6 <= dir(3) & '0' & dir(3);
      else
        dir6 <= dir(4) & "11";
      end if;
    end if;

    if (stage2_v(2) = '1') then
      if (sub3(10) = '0') then
        dir6 <= dir5;
      end if;
    end if;
  end process;
  
  r11_proc : process begin
    wait until rising_edge(i_clock);
    --if (stage2_v(2) = '1') then
      r17 <= sum6;
    --elsif (stage2_v(3) = '1') then
    --  if (sub2(13) = '0') then
    --    r17 <= unsigned(sub2(12 downto 0));
    --  else
    --    r17 <= to_unsigned(0,13);
    --  end if;
    --end if;
    r11 <= sum3;
  end process;

  r12_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(3) = '1') then
      r12 <= r6;
    elsif (stage2_v(0) = '1') then
      r12 <= sum5;
    elsif (stage2_v(1) = '1' and sub3(10) = '0') then
      r12 <= r13;
    end if;
  end process;

  r13_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(3) = '1') then
      r13 <= r5;
    elsif (stage2_v(0) = '1') then 
      r13 <= sum4;
    elsif (stage2_v(1) = '1') then
      r13 <= r16(9 downto 0);
    elsif (stage2_v(2) = '1' and sub3(10) = '1') then
      r13 <= r12;
    end if;
  end process;

  r16_proc : process begin
    wait until rising_edge(i_clock);
    if (stage2_v(0) = '1') then
      if (sub3(10) = '0') then
        r16 <= "000" & r13;
      else
        r16 <= "000" & r12;
      end if;
    elsif (stage2_v(2) = '1') then
      if (sub3(10) = '0') then
        r16 <= ("000" & r13) sll 3;
      else
        r16 <= ("000" & r12) sll 3;
      end if;
    end if;
  end process;

 -- sum3_src1 <= ("000" & (r4 and (8 downto 0 => stage2_v(0))))
 --           or ("00" & (r5 and (9 downto 0 => stage2_v(1))))
 --           or (r11(11 downto 0) and (11 downto 0 => (stage2_v(2) or stage2_v(3))));
 -- sum3_src2 <= ("0000" & (r7 and (7 downto 0 => stage2_v(0))))
 --           or ("00" & (r6 and (9 downto 0 => stage2_v(1))))
 --           or ((r11(11 downto 0) sll 1) and (11 downto 0 => (stage2_v(2) or stage2_v(3))));
  sum3_src1 <= "00" & r5 when stage2_v(0) = '1' else
               r11(11 downto 0);
  sum3_src2 <= "00" & r6 when stage2_v(0) = '1' else
               (r11(11 downto 0) sll 1);
  sum4_src1 <= r3;
  sum4_src2 <= '0' & r2(7 downto 0);
  sum5_src1 <= r4;
  sum5_src2 <= '0' & r7;

  sum6_src1 <= r11;
  sum6_src2 <= to_unsigned(384, 13);

 -- sub2_src1 <= ("000" & (r13 and (9 downto 0 => stage1_v(0))))
 --           or ("000" & (r12 and (9 downto 0 => stage1_v(1))))
 --           or ("000" & (r13 and (9 downto 0 => stage1_v(2))))
 --           or ((("000" & r13) sll 3) and (12 downto 0 => stage1_v(3)));
 -- sub2_src2 <= (b and (7 downto 0 => stage1_v(0)))
 --           or (d and (7 downto 0 => stage1_v(1)))
 --           or (f and (7 downto 0 => stage1_v(2)))
 --           or (h and (7 downto 0 => stage1_v(3)));

  --testt_proc : process begin
  --  wait until rising_edge(i_clock);
  --  if (stage1_v(3) = '1' or stage2_v(1) = '1') then
  --    sub2_src1 <= "000" & r13;
  --    sub2_src2 <= "000" & r12;
  --  elsif (stage2_v(0) = '1') then
  --    sub2_src1 <= "000" & r12;
  --    sub2_src2 <= r11;
  --  elsif (stage2_v(2) = '1') then
  --    sub2_src1 <= ("000" & r13) sll 3;
  --    sub2_src2 <= r11;
  --  end if;
  --end process;
  
  sub2_src1 <= r16;
  sub2_src2 <= r17;
  sub3_src1 <= r13;
  sub3_src2 <= r12;

  -- todo: maybe use a GE instead of sub. Will need to test.
  sub2 <= signed('0' & sub2_src1) - signed('0' & sub2_src2);
  sub3 <= signed('0' & sub3_src1) - signed('0' & sub3_src2);
  
  sum3 <= ('0' & sum3_src1) + ('0' & sum3_src2);
  sum4 <= ('0' & sum4_src1) + ('0' & sum4_src2);
  sum5 <= ('0' & sum5_src1) + ('0' & sum5_src2);
  sum6 <= (sum6_src1 + sum6_src2);
--------------------- END ------------------------
  o_edge <= not (sub2(13));
  o_dir <= std_logic_vector(dir6);

   
  --o_mode <= "01" when i_reset = '1' else
  --          "10" when counter = 0 else -- do better condition
  --          "11" when counter > 0; -- do better condition

  o_row_proc : process begin
    wait until rising_edge(i_clock);
    if (goto_init = '1') then
      o_row <= X"00";
    elsif (i_valid = '1') then
      o_row <= std_logic_vector(counter(15 downto 8)); 
    end if;
  end process;

  -- For debugging
  --o_mode(1) <= '1' when valid_parcel1 = '1' else '0';
  --o_mode(0) <= '1' when counter(8) = '1' else '0';
  --debug_num_0 <= std_logic_vector(sub2(3 downto 0));
  --debug_num_1 <= std_logic_vector(sub2(7 downto 4));
  --debug_num_2 <= std_logic_vector(sub2(11 downto 8));
  --debug_num_3 <= std_logic_vector("00" & sub2(13 downto 12));
  --debug_num_4 <= std_logic_vector("0000");
  --debug_num_5 <= std_logic_vector(unsigned("00" & std_logic_vector(r6(9 downto 8))));
end architecture;
