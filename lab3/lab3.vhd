library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package state_pkg is
  subtype state_ty is std_logic_vector(2 downto 0);
  constant S0 : state_ty := "001";
  constant S1 : state_ty := "010";
  constant S2 : state_ty := "100";

  subtype mem_data is unsigned(7 downto 0);
  type mem_data_vector is array(natural range <>) of mem_data;

  subtype calc_data is signed (9 downto 0); 
  type calc_data_vector is array(natural range <>) of calc_data;
end state_pkg;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.state_pkg.all;

entity lab3 is
  port (
    i_clock    : in std_logic;                     -- the system clock
    i_valid    : in std_logic;                     -- if data is available 
    i_input    : in std_logic_vector(7 downto 0);  -- input data
    i_reset    : in std_logic;                     -- reset
    o_output   : out std_logic_vector(7 downto 0)  -- output data
  );
end entity lab3;

architecture main of lab3 is
  signal output                   : unsigned(7 downto 0);
  signal count                    : unsigned(7 downto 0);
  signal calculation              : calc_data_vector(2 downto 0);
  signal counter                  : unsigned(8 downto 0); -- 5 MSB is the row count, 4 LSB is the column count
  signal q                        : mem_data_vector(2 downto 0);
  signal c                        : unsigned(7 downto 0);
  signal row_index                : state_ty;
  signal i_valid_and_row_index    : state_ty;
  signal goto_init                : std_logic;

   -- A function to rotate left (rol) a vector by n bits
  function "rol" ( a : std_logic_vector; n : natural )
  return std_logic_vector
  is
  begin
    return std_logic_vector( unsigned(a) rol n );
  end function;

begin
  c <= unsigned(i_input);

  calculation(0) <= signed(("00" & q(1)) - ("00" & q(2)) + ("00" & c));
  calculation(1) <= signed(("00" & q(2)) - ("00" & q(0)) + ("00" & c));
  calculation(2) <= signed(("00" & q(0)) - ("00" & q(1)) + ("00" & c));

  goto_init <= '1' when i_reset = '1' or counter(8) = '1' else
               '0';
  
  MEM_CPY: for I in 0 to 2 generate
    i_valid_and_row_index(I) <= i_valid and row_index(I);
    mem : entity work.mem(main)
    port map (
      address => std_logic_vector(counter(3 downto 0)), -- just column counter
      clock => i_clock,
      data => i_input,
      wren => i_valid_and_row_index(I),
      unsigned(q) => q(I)
    );
  end generate MEM_CPY;

  increment_counters : process
  begin
    wait until rising_edge(i_clock);
    if (goto_init = '1') then
      counter <= to_unsigned(0, 9);
    elsif (i_valid = '1') then
      counter <= counter + 1;
    end if;
  end process;

  rotate_row_index : process
  begin
    wait until rising_edge(i_clock);
    if (goto_init = '1') then
      row_index <= S0;
    elsif (i_valid = '1' and counter(3 downto 0) = 15) then
      row_index <= row_index rol 1;
    end if;
  end process;

  increment_count : process
  begin
    wait until rising_edge(i_clock);
    if (goto_init = '1') then
      count <= to_unsigned(0, 8);
    elsif (i_valid = '1' and counter(7 downto 5) > 0) then -- Once we reach row 2, start saving calculations
      if (row_index(0) = '1' and calculation(0) >= 0) then
        count <= count + 1;
      elsif (row_index(1) = '1' and calculation(1) >= 0) then
        count <= count + 1;
      elsif (row_index(2) = '1' and calculation(2) >= 0) then
        count <= count + 1;
      end if;
    end if;
  end process;

  -- Only display the final value and hold it until we parse new data
  store_output : process
  begin
    wait until rising_edge(i_clock);
    if (i_reset = '1') then
      output <= to_unsigned(0,8);
    elsif (counter(8) = '1') then
      output <= count;
    end if;
  end process;

  o_output <= std_logic_vector(output);
end architecture main;

-- Q1: number of flip flops and lookup tables?
-- Within our lab3 cell there was 80 lookup tables and 28 flip flops.
-- This was found using uw-synth --chip lab3.uwp

-- Q2: maximum clock frequency?
-- Our maximum clock frequency is 224 MHz for our lab3 cell
-- This was also found using uw-synth --chip lab3.uwp

-- Q3: source and destination signals of critical path?
-- The source of the critical path is reg_output/clk and the destination of the critical path is o_output

-- Q4: Was your design successful for all 5 tests?
-- Yes, all tests showed the correct value as stated in lab3_tb.vhd in both simulation and physical UART.
