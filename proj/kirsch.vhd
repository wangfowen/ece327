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

  signal mem_rd                   : mem_data_vector;
  signal i_valid_and_mem_row_index    : state_ty;
  signal mem_row_index                : state_ty;

  signal conv_vars                  : mem_data_crazy_vector;
  signal rd_c, rd_d                 : unsigned (7 downto 0);

  signal a, b, c,
         h,    d,
         g, f, e                 : unsigned(7 downto 0);

--------------------- STAGE1 ------------------------
  signal r1_s1                  : unsigned (8 downto 0);
  signal r2_s1                  : unsigned (8 downto 0); 
  signal r3_s1                  : unsigned (8 downto 0); 
  signal r4_s1                  : unsigned (8 downto 0); 
  signal r5_s1                  : unsigned (9 downto 0); 
  signal r6_s1                  : unsigned (9 downto 0); 
  signal r7_s1                  : unsigned (7 downto 0);
  signal r8_s1                  : unsigned (7 downto 0);
  signal r9_s1                  : unsigned (7 downto 0);
  signal r10_s1                 : unsigned (7 downto 0);
  
  signal sub_src1_s1            : unsigned (7 downto 0);
  signal sub_src2_s1            : unsigned (7 downto 0);
  signal sub_s1                 : signed (8 downto 0);
  signal sum1_src1_s1           : unsigned (8 downto 0);
  signal sum1_src2_s1           : unsigned (8 downto 0);
  signal sum1_s1                : unsigned (9 downto 0);
  signal sum2_src1_s1           : unsigned (8 downto 0);
  signal sum2_src2_s1           : unsigned (8 downto 0);
  signal sum2_s1                : unsigned (9 downto 0);

  signal dir1_s1                : unsigned (2 downto 0);
  signal dir2_s1                : unsigned (2 downto 0);
  signal dir3_s1                : unsigned (2 downto 0);
  signal dir4_s1                : unsigned (2 downto 0);

--------------------- STAGE2 ------------------------



--------------------- ENDVAR ------------------------

  signal valid_parcel1            : std_logic;
  signal valid_parcel2            : std_logic;
  signal goto_init                : std_logic;
  
  signal mode                     : mode_ty;
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

  carry_over_valid : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(3) = '1') then
      valid_parcel2 <= valid_parcel1;
    end if;
  end process;

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
  -- Done: R1, R2, R3, R4, R5, R6
  
  R1_S1_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(0) = '1') then
      r1_s1 <= sum1_s1(8 downto 0);
    end if;
  end process;

  R2_S1_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(0) = '1') then
      r2_s1 <= sum2_s1(8 downto 0); 
    end if;
  end process;
  
  R3_S1_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(2) = '1') then
      r3_s1 <= r5_s1(8 downto 0);
    end if;
  end process;
 
  R4_S1_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(2) = '1') then
      r4_s1 <= r6_s1(8 downto 0);
    end if;
  end process;
  
  R5_S1_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(1) = '1' or stage1_v(2) = '1') then
      r5_s1 <= sum1_s1;
    end if;
  end process;
  
  R6_S1_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(1) = '1' or stage1_v(2) = '1') then
      r6_s1 <= sum2_s1;
    end if;
  end process;

  R7_S1_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(0) = '1') then
      if (sub_s1(8) = '1') then
        dir1_s1 <= "100"; 
        r7_s1 <= b;
      else
        dir1_s1 <= "001"; 
        r7_s1 <= g;
      end if;
    end if;
  end process;

  R8_S1_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(1) = '1') then
      if (sub_s1(8) = '1') then
        dir2_s1 <= "110"; 
        r8_s1 <= d;
      else
        dir2_s1 <= "010"; 
        r8_s1 <= a;
      end if;
    end if;
  end process;

  R9_S1_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(2) = '1') then
      if (sub_s1(8) = '1') then
        dir3_s1 <= "101"; 
        r9_s1 <= f;
      else
        dir3_s1 <= "000"; 
        r9_s1 <= c;
      end if;
    end if;
  end process;

  R10_S1_proc : process begin
    wait until rising_edge(i_clock);
    if (stage1_v(3) = '1') then
      if (sub_s1(8) = '1') then
        dir4_s1 <= "111"; 
        r10_s1 <= h;
      else
        dir4_s1 <= "011"; 
        r10_s1 <= e;
      end if;
    end if;
  end process;
  
-- Todo: replace dis shit with tri-state
  sum1_src1_s1 <= '0' & h when stage1_v(0) = '1' else
                  '0' & d when stage1_v(1) = '1' else
                  r1_s1;
  sum1_src2_s1 <= '0' & a when stage1_v(0) = '1' else
                  '0' & e when stage1_v(1) = '1' else
                  '0' & r7_s1 when stage1_v(2) = '1' else
                  r2_s1 when stage1_v(3) = '1';
  sum2_src1_s1 <= '0' & b when stage1_v(0) = '1' else
                  '0' & f when stage1_v(1) = '1' else
                  r1_s1 when stage1_v(2) = '1' else
                  r3_s1 when stage1_v(3) = '1';
  sum2_src2_s1 <= '0' & c when stage1_v(0) = '1' else
                  '0' & g when stage1_v(1) = '1' else
                  '0' & r8_s1 when stage1_v(2) = '1' else
                  r4_s1 when stage1_v(3) = '1';

  sub_src1_s1 <=  g when stage1_v(0) = '1' else
                  a when stage1_v(1) = '1' else
                  c when stage1_v(2) = '1' else
                  e when stage1_v(3) = '1';
  sub_src2_s1 <=  b when stage1_v(0) = '1' else
                  d when stage1_v(1) = '1' else
                  f when stage1_v(2) = '1' else
                  h when stage1_v(3) = '1';
                 
  sub_s1 <= signed('0' & sub_src1_s1) - signed('0' & sub_src2_s1);
  sum1_s1 <= ('0' & sum1_src1_s1) + ('0' & sum1_src2_s1);
  sum2_s1 <= ('0' & sum2_src1_s1) + ('0' & sum2_src2_s1);

--------------------- STAGE2 ------------------------

  -- template 
  stage2_logic : process begin
    wait until rising_edge(i_clock);
    if (goto_init = '1') then
   
    elsif (stage1_v(3) = '1') then
     
    elsif (stage2_v(0) = '1') then
    
    elsif (stage2_v(1) = '1') then
    
    elsif (stage2_v(2) = '1') then

    elsif (stage2_v(3) = '1') then
    -- careful not to mix registers here (Remember unused)
   
    end if;
  end process;





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
  o_row <= std_logic_vector(sum1_s1(7 downto 0));
end architecture;
