------------------------------------------------------------------------
-- top level module for FIR filter
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fir_synth_pkg.all;

------------------------------------------------------------------------
-- key      0   reset
-- switch  0..6 changing frequency of sine wave
-- switch   17  input source
-- switch   16  output select
-- led_grn  09  clock
-- led_grn  10  reset (key 0) push
-- hex     4..7 sine wave frequency
------------------------------------------------------------------------
   
entity fir_top is
  port(
    ----------------------------------------------------
    clock_50    : in      std_logic;    -- 50MHz clock
    clock_27    : in      std_logic;    -- 27MHz clock
    ----------------------------------------------------
    key         : in      std_logic_vector(3 downto 0);   -- push buttons
    sw          : in      std_logic_vector(17 downto 0);  -- switches
    ledg        : out     std_logic_vector(8 downto 0);   -- green LED
    ledr        : out     std_logic_vector(17 downto 0);  -- red LED
    hex0,
    hex1,
    hex2,
    hex3,
    hex4,
    hex5,  
    hex6,
    hex7        : out   std_logic_vector(6 downto 0);     -- hex display
    ----------------------------------------------------
    aud_xck     : out   std_logic; -- codec master clock input
    aud_bclk    : inout std_logic; -- digital audio bit clock  WAS out
    aud_dacdat  : out   std_logic; -- DAC data lines
    aud_daclrck : out   std_logic; -- DAC data left/right select  WAS out
    aud_adclrck : out   std_logic; -- ADC data left/right select
    ----------------------------------------------------
    i2c_sdat    : inout std_logic; -- serial interface data line
    i2c_sclk    : out   std_logic  -- serial interface clock
    ----------------------------------------------------
    );
end entity;

architecture main of fir_top is
  
  --------------------------------------------------------------

  constant use_clock_50    : boolean := false;
  constant use_sample_1024 : boolean := false;
  
  --------------------------------------------------------------
  -- sine wave frequency selection and display
  
  signal display_freq      : std_logic_vector( 15 downto 0 );
  signal sine_freq         : unsigned(6 downto 0);

  --------------------------------------------------------------
  -- primary data signals

  signal sine_data
       , noise_data
       , audio_out
       : word;
  
  --------------------------------------------------------------
  -- audio chip signals

  -- index of bit (out of 16) to output to the serial port
  signal bit_position     : unsigned(3 downto 0);

  signal aud_ctrl_clk
       , data_clk
       , noise_clk
       : std_logic;
  
  signal serial_audio_out : std_logic;
  
begin

  --------------------------------------------------------------
  -- inputs and waveform generation

  sine_freq     <= unsigned( sw(  6 downto 0 ) );

  u_sine : entity work.sine_wave(sample_64)
    port map (
      clk        => data_clk,
      freq_scale => sine_freq,
      o_data     => sine_data
    );

  u_noise : entity work.white_noise(main)
    generic map (
      use_clock_50  => false
    )
    port map (
      clk    => data_clk,   
      o_data => noise_data
    );
      
  --------------------------------------------------------------
  -- core

  process begin
    wait until rising_edge( data_clk );
    audio_out <= sine_data;
  end process;
  
  --------------------------------------------------------------
  -- outputs

  ----------------------------------------------------
  
  display_freq <= frequency_map( to_integer ( sine_freq ) );

  hex7 <= to_sevenseg( unsigned(display_freq(15 downto 12)) );
  hex6 <= to_sevenseg( unsigned(display_freq(11 downto  8)) );
  hex5 <= to_sevenseg( unsigned(display_freq( 7 downto  4)) );
  hex4 <= to_sevenseg( unsigned(display_freq( 3 downto  0)) );

  hex3 <= (others => 'Z');
  hex2 <= (others => 'Z');
  hex1 <= (others => 'Z');
  hex0 <= (others => 'Z');
  
  ----------------------------------------------------
  -- serial output for audio
  
  -- Generate the audio stream bit to send to the CODEC
  -- Note that the CODEC supports stereo but all processing is mono

  sample_bit_clk: process (aud_bclk)
  begin
    if rising_edge(aud_bclk) then
      -- increment bit to send on the clock      
      bit_position <= bit_position + 1;
    end if;
  end process;
    
  serial_audio_out <= audio_out(to_integer(15 - bit_position));
  
  aud_dacdat       <= serial_audio_out;
  
  --------------------------------------------------------------
  -- audio peripheral
  --
  
  ----------------------------------------------------
  -- provide clocks to ADC and DAC and bit clock for serial data
  aud_adclrck <= data_clk;
  aud_daclrck <= data_clk;
  aud_xck     <= aud_ctrl_clk;
  
  u_audio_dac : entity work.audio_dac port map
    (
        clock_27    => clock_27          -- 27 MHz clock
      , clock_18_4    => aud_ctrl_clk      -- PLL clock 14.8 MHz
      , reset_n       => key(0)            -- reset
      , o_aud_bck     => aud_bclk
      , o_aud_lrck    => data_clk          --  Audio Side
    );
  
  --------------------------------------------------------------
  -- I2C communications to the CODEC
  --
  u_i2c_av_config : entity work.i2c_av_config
    port map (
        clk     => clock_27
      , i2c_sclk => i2c_sclk
      , i2c_sdat => i2c_sdat
    );
  --------------------------------------------------------------
  
end architecture;
  
