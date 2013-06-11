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
  -- TODO: Test all test inputs for the testbench in simulator (There are 5 tests you can use)
  -- TODO: Test on board
  -- TODO: Fill in Questions 

  -- COMMENT(Delete THIS): I resolved the end condition by letting our counter be 8 bits.
  -- If counter = 1, then we can reset count. This is basically the behaviour we wanted, without fucking up our clock cycles.
  -- You can look at the code below.

  -- COMMENT (DELETE THIS): I tried to write up a and b in a different manner using and and or's.
  -- There was a clever way you could do it but you end up with the same number of LUTS, so might as well use multiplexer's
  -- If for some reason the multiplexers are causing the bad timing, we can revert back to this implementation, but I doubt it's 
  -- what is causing the bad timing.
  
  -- TODO: Test corner cases 255 + 255 and -255
  
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
    if (goto_init = '1') then
      output <= count;
    end if;
  end process;

  o_output <= std_logic_vector(output);
end architecture main;

-- Q1: number of flip flops and lookup tables?
--

-- Q2: maximum clock frequency?
--

-- Q3: source and destination signals of critical path?
-- 
