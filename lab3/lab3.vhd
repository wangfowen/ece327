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
  signal count : unsigned(7 downto 0);
  signal calculation : signed(9 downto 0);
  signal row_counter : unsigned(3 downto 0);
  signal row_index : unsigned(3 downto 0);
  signal column_counter : unsigned(3 downto 0);
  signal address1
       , address2
       , address3
       : std_logic_vector(3 downto 0);
  signal data1
       , data2
       , data3
       , q1
       , q2
       , q3
       : std_logic_vector(7 downto 0);
  signal a
       , b
       , c
       : unsigned(9 downto 0);

   -- A function to rotate left (rol) a vector by n bits
  function "rol" ( a : std_logic_vector; n : natural )
  return std_logic_vector
  is
  begin
      return std_logic_vector( unsigned(a) rol n );
  end function;

begin
  mem1 : entity work.mem(main)
    port map (
      address => address1,
      clock => i_clock,
      data => data1,
      wren => i_valid,
      q => q1
    );
  mem2 : entity work.mem(main)
    port map (
      address => address2,
      clock => i_clock,
      data => data2,
      wren => i_valid,
      q => q2
    );
  mem3 : entity work.mem(main)
    port map (
      address => address3,
      clock => i_clock,
      data => data3,
      wren => i_valid,
      q => q3
    );

  -- TODO: make these what they actually should be
  a <= unsigned("00" & i_input);
  b <= to_unsigned(100, 10);
  c <= a;

  do_calculation : process
  begin
    wait until rising_edge(i_clock);
  -- when push button 0 is pressed and before each matrix set, set reset to 1

  -- if reset is 1:
  -- clear matrix, set state to 000, counter to 0x00

  -- TODO: Test corner cases 255 + 255 and -255
    -- address of row_index's mem is column_counter
    -- set data of row_index's mem to be i_input
    -- grab q from row_index's mem
    -- TODO: change system to work with valid bit states
    if i_valid = '1' then
      data1 <= i_input;
      address1 <= std_logic_vector(column_counter);
      -- TODO: if it's after row 2 column 0, also do calculation
      calculation <= signed( a - b + c );
      if calculation >= 0 then
        count <= count + 1;
      end if;
    end if;
  end process;

  increment_counters : process
  begin
    wait until rising_edge(i_clock);

    if i_valid = '1' then
      column_counter <= column_counter + 1;
      -- TODO: mod through column_counter 
      -- TODO: when hit max of column_counter mod through row_index and increment row_counter if it's < 15
    end if;
  end process;

  o_output <= q1;
end architecture main;

-- Q1: number of flip flops and lookup tables?
--

-- Q2: maximum clock frequency?
--

-- Q3: source and destination signals of critical path?
-- 

