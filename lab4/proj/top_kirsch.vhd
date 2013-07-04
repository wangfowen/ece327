-------------------------------------------------------------------------------
-- top_kirsch.vhd
-- top level code for kirsch edge detector
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.kirsch_synth_pkg.all;

entity top_kirsch is
  port (
    ------------------------------------------
    -- main inputs and outputs
    nrst                : in  std_logic;  -- reset pin
    clk                 : in  std_logic;  -- clock
    rxflex              : in  std_logic;  -- rx uart input
    txflex              : out std_logic;  -- tx uart output
    o_sevenseg          : out std_logic_vector(15 downto 0);  --sevenseg output
    o_mode 		: out std_logic_vector( 1 downto 0);  -- o_mode signal
    o_nrst              : out std_logic;  -- output of reset,
    ------------------------------------------
    -- debugging inputs and outputs
    debug_key           : in  std_logic_vector( 3 downto 1) ; 
    debug_switch        : in  std_logic_vector(17 downto 0) ; 
    debug_led_red       : out std_logic_vector(16 downto 0) ; 
    debug_led_grn       : out std_logic_vector(5  downto 0) ; 
    debug_sevenseg_0    : out std_logic_vector(7 downto 0) ; 
    debug_sevenseg_1    : out std_logic_vector(7 downto 0) ; 
    debug_sevenseg_2    : out std_logic_vector(7 downto 0) ; 
    debug_sevenseg_3    : out std_logic_vector(7 downto 0) ; 
    debug_sevenseg_4    : out std_logic_vector(7 downto 0) ;
    debug_sevenseg_5    : out std_logic_vector(7 downto 0) 
    ------------------------------------------
  );
end entity;


architecture main of top_kirsch is

  signal rst            : std_logic;
  signal pixavail       : std_logic;
  signal pixel          : std_logic_vector (7 downto 0);
  signal o_valid        : std_logic;
  signal kirschout      : std_logic;
  signal dir            : std_logic_vector(2 downto 0);
  signal mode           : std_logic_vector(1 downto 0);
  signal rowcount       : std_logic_vector(7 downto 0);

  signal debug_num_0
       , debug_num_1
       , debug_num_2
       , debug_num_3
       , debug_num_4
       , debug_num_5
       : std_logic_vector(3 downto 0);

  signal NC : std_logic;
  
begin

  rst <= not(nrst);
  
  u_uw_uart :  entity work.uw_uart(main)
    port map (
      clk        => clk,
      rst        => rst,
      rxflex     => rxflex,
      datain     => pixel,
      txflex     => txflex,
      kirschout  => kirschout,
      kirschdir  => dir,
      o_valid    => o_valid,
      o_pixavail => pixavail,
      i_mode     => mode
    );
  
  u_kirsch: entity work.kirsch(main)
    port map(
      i_clock       => clk,
      i_valid       => pixavail, 
      i_pixel       => pixel,
      i_reset       => rst,
      o_edge        => kirschout,
      o_valid       => o_valid,
      o_dir         => dir,
      o_mode        => mode,
      o_row         => rowcount,
      debug_key     => debug_key,
      debug_switch  => debug_switch,
      debug_led_red(16 downto 0) => debug_led_red,
      debug_led_red(17) => NC,
      debug_led_grn => debug_led_grn, 
      debug_num_0   => debug_num_0,
      debug_num_1   => debug_num_1,
      debug_num_2   => debug_num_2,
      debug_num_3   => debug_num_3,
      debug_num_4   => debug_num_4,
      debug_num_5   => debug_num_5
    );

  o_sevenseg <=
      to_sevenseg( unsigned(rowcount(7 downto 4)), '0' )
    & to_sevenseg( unsigned(rowcount(3 downto 0)), '0' )
    when rising_edge( clk );
    
  debug_sevenseg_0 <= 
      to_sevenseg( unsigned(debug_num_0), '0' )
      when rising_edge( clk );
    
  debug_sevenseg_1 <=
      to_sevenseg( unsigned(debug_num_1), '0' )
      when rising_edge( clk );
    
  debug_sevenseg_2 <=
      to_sevenseg( unsigned(debug_num_2), '0' )
      when rising_edge( clk );
    
  debug_sevenseg_3 <=
      to_sevenseg( unsigned(debug_num_3), '0' )
      when rising_edge( clk );
    
  debug_sevenseg_4 <=
      to_sevenseg( unsigned(debug_num_4), '0' )
      when rising_edge( clk );
    
  debug_sevenseg_5 <=
      to_sevenseg( unsigned(debug_num_5), '0' )
      when rising_edge( clk );
    
  o_mode <= mode;
  o_nrst <= rst;
  
end architecture;

