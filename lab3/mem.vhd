library ieee;
use ieee.std_logic_1164.all ;
use ieee.numeric_std.all ;

entity mem is
  generic (
    data_width : natural := 8 ;
    addr_width : natural := 4);
  port (
    address  : in std_logic_vector(addr_width - 1 downto 0) ;
    clock    : in std_logic;
    data     : in std_logic_vector(data_width - 1 downto 0) ;
    wren     : in std_logic;
    q        : out std_logic_vector(data_width - 1 downto 0)
    );
end mem ;


architecture main of mem is
  type mem_type is array (2**addr_width-1 downto 0) of
    std_logic_vector(data_width - 1 downto 0) ;
  signal mem        : mem_type ;
  signal mem_output : std_logic_vector(data_width - 1 downto 0);
  signal rd_disable : std_logic;
begin
  proc : process (clock)
  begin
    if rising_edge(clock) then
      if wren = '1' then
        mem( to_integer(unsigned(address)) ) <= data ;
      end if ;
      mem_output <= mem( to_integer(unsigned(address)) );
    end if ;
  end process;

  process (clock)
  begin
    if rising_edge(clock) then
      rd_disable <= wren;
    end if;
  end process;

  q <=   (others => 'X') when rd_disable='1'
    else mem_output;
  
end main;

