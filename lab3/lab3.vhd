library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package state_pkg is
  subtype state_ty is std_logic_vector(2 downto 0);
  constant S0 : state_ty := "001";
  constant S1 : state_ty := "010";
  constant S2 : state_ty := "100";

  subtype mem_address is unsigned(3 downto 0);
  type mem_address_vector is array(natural range <> ) of mem_address;
  
  subtype mem_data is unsigned(7 downto 0);
  type mem_data_vector is array(natural range <>) of mem_data; 
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
  signal address : mem_address_vector(2 downto 0);
  signal data
       , q
       : mem_data_vector(2 downto 0);
  signal a
       , b
       , c
       : unsigned(7 downto 0);
  signal state : state_ty;
  signal row_index : state_ty;
  signal row_index_and_i_valid : state_ty;

  -- Optimization signals
  signal valid_sig_no_reset : std_logic;
  signal goto_init : std_logic;

   -- A function to rotate left (rol) a vector by n bits
  function "rol" ( a : std_logic_vector; n : natural )
  return std_logic_vector
  is
  begin
      return std_logic_vector( unsigned(a) rol n );
  end function;

begin
  goto_init <= '1' when row_counter >= 15 and column_counter >= 15
              else '0';
  c <= unsigned(i_input);

  MEM_CPY: for I in 0 to 2 generate
    row_index_and_i_valid(I) <= i_valid and row_index(I);
    mem : entity work.mem(main)
    port map (
      address => std_logic_vector(column_counter),
      clock => i_clock,
      data => i_input,
      wren => row_index_and_i_valid(I),
      unsigned(q) => q(I)
    );
  end generate MEM_CPY;

  store_input : process
  begin
    wait until rising_edge(i_clock);
    
    if i_valid = '1' then
      -- Store input into memory

      if (row_counter >= 2) then
        -- TODO MAKE THIS COMBINATIONAL!!!
        if (row_index(0) = '1') then
          a <= q(1);
          b <= q(2);
        elsif (row_index(1) = '1') then
          a <= q(2);
          b <= q(0);
        else
          a <= q(0);
          b <= q(1);
        end if;

        -- TODO: Test corner cases 255 + 255 and -255
        calculation <= signed(("00" & a) - ("00" & b) + ("00" & c));

        -- TODO add to count
      end if;
    end if;
  end process;

  increment_counters : process
  begin
    wait until rising_edge(i_clock);
    -- TODO reset state after end of matrix with goto_init and test optimizations
    -- TODO check if making each counter/state machine its own process will help optimizations

    if (i_reset = '1') then     
      column_counter <= to_unsigned(0, 4);
      row_counter <= to_unsigned(0, 4);
      count <= to_unsigned(0, 8);

    elsif (i_valid = '1') then
     
      if (column_counter >= 15) then
        column_counter <= to_unsigned(0, 4);
        row_counter <= row_counter + 1;
      else
        column_counter <= column_counter + 1;
      end if;
    
    end if;
  end process;

  rotate_row_index : process
  begin
    wait until rising_edge(i_clock);

    if (i_reset = '1') then
      row_index <= S0;

    elsif (i_valid = '1') then  
      if (column_counter >= 15) then
        row_index <= row_index rol 1;
      end if;
    end if;
  end process;

  o_output <= std_logic_vector(q(0));
end architecture main;

-- Q1: number of flip flops and lookup tables?
--

-- Q2: maximum clock frequency?
--

-- Q3: source and destination signals of critical path?
-- 
