------------------------------------------------------------------------
-- This memory model works correctly in all simulation modes, 
-- and synthesizes correctly onto the FPGA board.
-- 
-- Some *other* memory models trigger an apparent bug in either Quartus
-- or Modelsim that causes timing simulation to add an extra clock cycle
-- of latency to memory accesses.
--
-- However, this coding style is deprecated by Quartus.  The Quartus
-- coding handbook warns that this is a new-data read-during-write
-- behaviour, which is deprecated in favour of old-data read-during-write
-- behaviour.  The reason is that some synthesis tools might not infer a
-- RAM, or might add extra bypass logic.  
--
-- This code synthesizes correctly with PrecisionRTL and Quartus.
-- 
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all ;
use ieee.numeric_std.all ;

entity mem is
  generic (
    data_width : natural := 8 ;
    addr_width : natural := 8);
  port (
    address  : in std_logic_vector(addr_width - 1 downto 0) ;
    clock    : in std_logic;
    data     : in std_logic_vector(data_width - 1 downto 0) ;
    wren     : in std_logic;
    q        : out std_logic_vector(data_width - 1 downto 0)
    );
end mem ;


architecture main of mem is
  signal reg_address  : std_logic_vector(addr_width - 1 downto 0) ;
  type mem_type is array (2**addr_width-1 downto 0) of
    std_logic_vector(data_width - 1 downto 0) ;
  signal mem        : mem_type ;
  signal rd_disable : std_logic;

  attribute ramstyle : string;
  attribute ramstyle of mem : signal is "no_rw_check";
  
begin

  process (clock)
  begin
    if rising_edge(clock) then
      reg_address <= address;
    end if;
  end process;
  
  process (clock)
  begin
    if rising_edge(clock) then
      if wren = '1' then
        mem( to_integer(unsigned(address)) ) <= data ;
      end if ;
    end if ;
  end process;
  
  process (clock)
  begin
    if rising_edge(clock) then
      rd_disable <= wren;
    end if;
  end process;

  q <=   (others => 'X') when rd_disable='1'
    else mem( to_integer(unsigned(reg_address)) );
  
end main;

