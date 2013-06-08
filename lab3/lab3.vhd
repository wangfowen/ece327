library ieee;
use ieee.std_logic_1164.all;

package state_pkg is
  subtype state_ty is std_logic_vector(2 downto 0);
  constant S0 : state_ty := "001";
  constant S1 : state_ty := "010";
  constant S2 : state_ty := "100";
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
  signal count : unsigned(7 downto 0);
  signal calculation : signed(9 downto 0);
  signal row_counter : unsigned(3 downto 0);
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
  signal state : state_ty;
  signal row_index : state_ty;

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

  set_state : process
  begin
    wait until rising_edge(i_clock);
    -- TODO: state 0 if push button 0 pressed also
    --if (row_counter = 0 and column_counter = 0) then
    --  state <= S0;
    --end if;

    if (i_valid = '1' and row_counter = 0 and column_counter = 0) then
      -- state 1 - increment without calculations
      state <= state rol 1;
    elsif (i_valid = '1' and row_counter = 2 and column_counter = 0) then
      -- state 2 - start calculations
      state <= state rol 1;
    end if;
  end process;

  store_input : process
  begin
    wait until rising_edge(i_clock);
  -- TODO: Test corner cases 255 + 255 and -255
    if (i_valid = '1' and (state(1) or state(2)) = '1') then
      if (row_index(0) = '1') then
        data1 <= i_input;
        address1 <= std_logic_vector(column_counter);
      elsif (row_index(1) = '1') then
        data2 <= i_input;
        address2 <= std_logic_vector(column_counter);
      else
        data3 <= i_input;
        address3 <= std_logic_vector(column_counter);
      end if;

      if (state(2) = '1') then
        -- TODO: actulally do calculations correctly
        a <= unsigned("00" & i_input);
        b <= to_unsigned(100, 10);
        c <= a;
        calculation <= signed( a - b + c );
      end if;
    end if;
  end process;

  increment_counters : process
  begin
    wait until rising_edge(i_clock);

    if (i_valid = '1' and (state(1) or state(2)) = '1') then
      if (column_counter = 15) then
        column_counter <= to_unsigned(0, 4);
        row_counter <= row_counter + 1;
        row_index <= row_index rol 1;
      else
        column_counter <= column_counter + 1;
      end if;

      if (state(2) = '1' and calculation >= 0) then
        count <= count + 1;
      end if;
    elsif (state(0) = '1') then
      column_counter <= to_unsigned(0, 4);
      row_counter <= to_unsigned(0, 4);
      row_index <= S0;
      count <= to_unsigned(0, 8);
    end if;
  end process;

  o_output <= std_logic_vector(count);
end architecture main;

-- Q1: number of flip flops and lookup tables?
--

-- Q2: maximum clock frequency?
--

-- Q3: source and destination signals of critical path?
-- 
