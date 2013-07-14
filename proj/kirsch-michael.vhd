
library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


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
    o_row      : out std_logic_vector(7 downto 0)
    -- ------------------------------------------
    -- -- debugging inputs and outputs
    -- debug_key      : in  std_logic_vector(3  downto 1); 
    -- debug_switch   : in  std_logic_vector(17 downto 0); 
    -- debug_led_red  : out std_logic_vector(17 downto 0); 
    -- debug_led_grn  : out std_logic_vector(5  downto 0); 
    -- debug_num_0    : out std_logic_vector(3  downto 0); 
    -- debug_num_1    : out std_logic_vector(3  downto 0); 
    -- debug_num_2    : out std_logic_vector(3  downto 0); 
    -- debug_num_3    : out std_logic_vector(3  downto 0); 
    -- debug_num_4    : out std_logic_vector(3  downto 0);
    -- debug_num_5    : out std_logic_vector(3  downto 0) 
    -- ------------------------------------------
  );  
end entity;


architecture main of kirsch is
  signal cell_counter : unsigned(16 downto 0);
  signal rotation_state : unsigned(8 downto 0);
  signal row_state : unsigned(2 downto 0);
  signal o_mem_dat : std_logic_vector(95 downto 0);
  signal input_reg : std_logic_vector(7 downto 0);
  signal mem_4 : std_logic_vector(31 downto 0);
  signal address_4 : std_logic_vector(31 downto 0);
  signal addr1, addr2, addr3 : std_logic_vector(7 downto 0);
  signal mem_wren : std_logic_vector(11 downto 0);
  signal mem_rden : std_logic_vector(11 downto 0);
  signal counter_flip_reg : std_logic;
  signal diff_reg : signed(8 downto 0);
  signal max_reg : unsigned(8 downto 0);
  signal sum_reg : unsigned(10 downto 0);
  signal dir_reg : std_logic_vector(2 downto 0);
  signal done_round : std_logic;
  signal is_o_valid : std_logic;
  signal o_row_reg : std_logic_vector(15 downto 0);
begin

process(i_clock)
  variable five_sum : unsigned(8 downto 0);
  variable diff : signed(8 downto 0);
begin
if (rising_edge(i_valid)) then
  input_reg <= i_pixel;
end if;

if (rising_edge(i_clock)) then
if (i_reset = '1' or cell_counter(16) = '1') then
  --o_output <= std_logic_vector(counter);
  --counter <= "00000000";
  row_state <= "001";
  rotation_state <=  (rotation_state'LENGTH - 1 downto 1 => '0') & '1';
  cell_counter <=  (cell_counter'LENGTH - 1 downto 0 => '0');
  addr1 <= "00000000";
  addr2 <= "00000001";
  addr3 <= "00000010";
  diff_reg <= "000000000";
  sum_reg <= "00000000000";
else
  if (rotation_state(7) = '1') then 
    is_o_valid <= '1';
    addr1 <= addr2;
    addr2 <= addr3;
    addr3 <= std_logic_vector(unsigned(addr3) + 1);
  else 
    is_o_valid <= '0';
  end if;
  if (i_valid = '1' or done_round = '0') then
    if(cell_counter(8) /= counter_flip_reg) then -- when column_counter rolls over, shift to rotate the row state.
      row_state <= row_state rol 1;
      counter_flip_reg <= cell_counter(16);
    end if;
    five_sum := unsigned('0' & mem_4(15 downto 8)) + 
                unsigned('0' & mem_4(23 downto 16)) +
                unsigned('0' & mem_4(31 downto 24));
    diff := (signed('0' & mem_4(7 downto 0)) -
             signed('0' & mem_4(31 downto 24))) +
             signed(diff_reg);
    sum_reg <= unsigned(sum_reg) + unsigned(mem_4(7 downto 0));
    if (diff(8) = '1') then
      diff_reg <= "000000000";
      max_reg <= five_sum;
      dir_reg <= "000";
      if (rotation_state(0) = '1') then
        dir_reg <= "001";
      elsif (rotation_state(1) = '1') then
        dir_reg <= "100";
      elsif (rotation_state(2) = '1') then
        dir_reg <= "010";
      elsif (rotation_state(3) = '1') then
        dir_reg <= "110";
      elsif (rotation_state(4) = '1') then
        dir_reg <= "000";
      elsif (rotation_state(5) = '1') then
        dir_reg <= "101";
      elsif (rotation_state(6) = '1') then
        dir_reg <= "011";
      elsif (rotation_state(7) = '1') then
        dir_reg <= "111";
      end if;
    else 
      diff_reg <= diff;
    end if;
    done_round <= rotation_state(7);
    rotation_state <= rotation_state rol 1;
    cell_counter <= cell_counter + 1;
  end if;
end if;
end if;
end process;

o_mode <= "11";

process(is_o_valid, dir_reg, cell_counter, max_reg, sum_reg)
  variable shift_max : unsigned(11 downto 0); 
begin
  o_row <= std_logic_vector(cell_counter(15 downto 8));
  o_dir <= dir_reg;
  o_valid <= is_o_valid;
  o_edge <= '0';
  shift_max := ("000" & max_reg) rol 3;
  if (is_o_valid = '1') then
    if (shift_max - (("0" & sum_reg) + ("0" & sum_reg rol 1))) >= 384 then
      o_edge <= '1';
    end if;
  end if;
end process;

  GENWRENA: for I in 0 to 2 generate
  GENWRENB: for A in 0 to 3 generate
    mem_wren(A * 3 + I) <= rotation_state(5 - A) and row_state(I);
  end generate GENWRENB;
  end generate GENWRENA;

  GENRDENB: for A in 0 to 3 generate
  GENRDENA: for I in 0 to 2 generate
    mem_rden(A * 3 + I) <= ((rotation_state((3 + 8 - A) mod 8) or 
                             rotation_state((4 + 8 - A) mod 8) or 
                             rotation_state((5 + 8 - A) mod 8)) and
                            row_state((3 - I) mod 3)) or
                           ((rotation_state((2 + 8 - A) mod 8) or
                             rotation_state((6 + 8 - A) mod 8)) and
                            row_state((4 - I) mod 3)) or
                           ((rotation_state((7 + 8 - A) mod 8) or
                             rotation_state((0 + 8 - A) mod 8) or
                             rotation_state((1 + 8 - A) mod 8)) and
                            row_state((5 - I) mod 3));
  end generate GENRDENA;
  end generate GENRDENB;


  GENC: for I in 0 to 2 generate
  GENA: for A in 0 to 3 generate
  mem_block : entity work.zmem(main)
    port map (
      address => address_4((A * 8) + 7 downto A * 8),
      clock => i_clock,
      data => input_reg,
      wren => mem_wren(A * 3 + I),
      rden => mem_rden(A * 3 + I),
      q => o_mem_dat((A * 24) + (I * 8) + 7 downto (A * 24) + (I * 8))
    );
    mem_4((A * 8) + 7 downto A * 8) <= o_mem_dat((A * 24) + (I * 8) + 7 downto (A * 24) + (I * 8));
  end generate GENA;
  end generate GENC;
  
  GENADDR: for I in 0 to 3 generate
  address_4(I * 8 + 7 downto I * 8) <= addr1 when 
    (rotation_state((9 - I) mod 8) = '1' or 
     rotation_state((10 - I) mod 8) = '1' or
     rotation_state((11 - I) mod 8) = '1') else 
    (others => 'Z');
  address_4(I * 8 + 7 downto I * 8) <= addr2 when 
    (rotation_state((12 - I) mod 8) = '1' or
     rotation_state((8 - I) mod 8) = '1') else
    (others => 'Z');
  address_4(I * 8 + 7 downto I * 8) <= addr3 when 
    (rotation_state((13 - I) mod 8) = '1' or
     rotation_state((14 - I) mod 8) = '1' or
     rotation_state((15 - I) mod 8) = '1') else
    (others => 'Z');
  address_4(I * 8 + 7 downto I * 8) <= ( others => 'L' ); -- pullup
  end generate GENADDR;

  -- debug_num_5 <= X"E";
  -- debug_num_4 <= X"C";
  -- debug_num_3 <= X"E";
  -- debug_num_2 <= X"3";
  -- debug_num_1 <= X"2";
  -- debug_num_0 <= X"7";

  -- debug_led_red <= (others => '0');
  -- debug_led_grn <= (others => '0');


end architecture;
