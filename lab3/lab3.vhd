library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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
  signal count : unsigned(7 downto 0) := to_unsigned(0, 8);
  signal calculation : signed(9 downto 0);
  signal row_counter : unsigned(3 downto 0) := to_unsigned(0, 4);
  signal column_counter : unsigned(3 downto 0) := to_unsigned(0, 4);

   -- A function to rotate left (rol) a vector by n bits
  function "rol" ( a : std_logic_vector; n : natural )
  return std_logic_vector
  is
  begin
      return std_logic_vector( unsigned(a) rol n );
  end function;
begin
  calc : process
  begin
    wait until rising_edge(i_clock);
  -- when push button 0 is pressed and before each matrix set, set reset to 1

  -- if reset is 1:
  -- clear matrix, set state to 000, counter to 0x00

  -- when i_valid is 1:
    if unsigned(i_input) >= 10 then
      count <= count + 1;
    end if;
  -- store data in matrix
  -- if it's after row 2 column 0, also do calculation and increment count
  -- put count on seven segment display
  end process;

  o_output <= std_logic_vector(count);
end architecture main;

-- Q1: number of flip flops and lookup tables?
--

-- Q2: maximum clock frequency?
--

-- Q3: source and destination signals of critical path?
-- 

