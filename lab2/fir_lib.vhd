------------------------------------------------------------------------
-- sine wave
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fir_synth_pkg.all;

entity sine_wave is
  port (
    clk        : in std_logic;
    freq_scale : in unsigned( 6 downto 0 );
    o_data     : out word
  );
end entity;

------------------------------------------------------------------------
-- architecture with 1024 entries

architecture sample_1024 of sine_wave is

  constant sine_waveform_map : word_vector( 0 to 255 ) :=
  (
      x"0000", x"00c9", x"0192", x"025b", x"0324", x"03ed", x"04b6",
      x"057f", x"0647", x"0710", x"07d9", x"08a2", x"096a", x"0a33",
      x"0afb", x"0bc3", x"0c8b", x"0d53", x"0e1b", x"0ee3", x"0fab",
      x"1072", x"1139", x"1201", x"12c8", x"138e", x"1455", x"151b",
      x"15e2", x"16a8", x"176d", x"1833", x"18f8", x"19bd", x"1a82",
      x"1b47", x"1c0b", x"1ccf", x"1d93", x"1e56", x"1f19", x"1fdc",
      x"209f", x"2161", x"2223", x"22e5", x"23a6", x"2467", x"2528",
      x"25e8", x"26a8", x"2767", x"2826", x"28e5", x"29a3", x"2a61",
      x"2b1f", x"2bdc", x"2c98", x"2d55", x"2e11", x"2ecc", x"2f87",
      x"3041", x"30fb", x"31b5", x"326e", x"3326", x"33de", x"3496",
      x"354d", x"3604", x"36ba", x"376f", x"3824", x"38d8", x"398c",
      x"3a40", x"3af2", x"3ba5", x"3c56", x"3d07", x"3db8", x"3e68",
      x"3f17", x"3fc5", x"4073", x"4121", x"41ce", x"427a", x"4325",
      x"43d0", x"447a", x"4524", x"45cd", x"4675", x"471c", x"47c3",
      x"4869", x"490f", x"49b4", x"4a58", x"4afb", x"4b9e", x"4c3f",
      x"4ce1", x"4d81", x"4e21", x"4ebf", x"4f5e", x"4ffb", x"5097",
      x"5133", x"51ce", x"5269", x"5302", x"539b", x"5433", x"54ca",
      x"5560", x"55f5", x"568a", x"571d", x"57b0", x"5842", x"58d4",
      x"5964", x"59f3", x"5a82", x"5b10", x"5b9d", x"5c29", x"5cb4",
      x"5d3e", x"5dc7", x"5e50", x"5ed7", x"5f5e", x"5fe3", x"6068",
      x"60ec", x"616f", x"61f1", x"6271", x"62f2", x"6371", x"63ef",
      x"646c", x"64e8", x"6563", x"65dd", x"6657", x"66cf", x"6746",
      x"67bd", x"6832", x"68a6", x"6919", x"698c", x"69fd", x"6a6d",
      x"6adc", x"6b4a", x"6bb8", x"6c24", x"6c8f", x"6cf9", x"6d62",
      x"6dca", x"6e30", x"6e96", x"6efb", x"6f5f", x"6fc1", x"7023",
      x"7083", x"70e2", x"7141", x"719e", x"71fa", x"7255", x"72af",
      x"7307", x"735f", x"73b5", x"740b", x"745f", x"74b2", x"7504",
      x"7555", x"75a5", x"75f4", x"7641", x"768e", x"76d9", x"7723",
      x"776c", x"77b4", x"77fa", x"7840", x"7884", x"78c7", x"7909",
      x"794a", x"798a", x"79c8", x"7a05", x"7a42", x"7a7d", x"7ab6",
      x"7aef", x"7b26", x"7b5d", x"7b92", x"7bc5", x"7bf8", x"7c29",
      x"7c5a", x"7c89", x"7cb7", x"7ce3", x"7d0f", x"7d39", x"7d62",
      x"7d8a", x"7db0", x"7dd6", x"7dfa", x"7e1d", x"7e3f", x"7e5f",
      x"7e7f", x"7e9d", x"7eba", x"7ed5", x"7ef0", x"7f09", x"7f21",
      x"7f38", x"7f4d", x"7f62", x"7f75", x"7f87", x"7f97", x"7fa7",
      x"7fb5", x"7fc2", x"7fce", x"7fd8", x"7fe1", x"7fe9", x"7ff0",
      x"7ff6", x"7ffa", x"7ffd", x"7fff"
      );

  --------------------------------------------------------------
  
  signal clock_count
       , sine_count        : unsigned(20 downto 0);
  
  signal address           : unsigned(9 downto 0);

  signal quarter_sine_data
       , sine_data         : word;
  
  --------------------------------------------------------------
  
begin

  process begin
    wait until rising_edge(clk);
    clock_count <= clock_count + 1;
    sine_count  <= clock_count srl to_integer( freq_scale );
    address     <= sine_count( 9 downto 0 );
  end process;

  quarter_sine_data <=
    sine_waveform_map( to_integer( address(7 downto 0) ) );

  with address( 9 downto 8 ) select
    sine_data <= quarter_sine_data when "00"
              , x"7FFF" - quarter_sine_data when "01"   
              , x"0000" - quarter_sine_data when "10"   
              , x"8000" + quarter_sine_data when others;

  process begin
    wait until rising_edge(clk);
    o_data <= sine_data sra num_bits_mantissa;
  end process;

end architecture;

------------------------------------------------------------------------
-- architecture with 64 entries
--
-- clock must be data clock from audio D-to-A converter
-- freq_scale is increment amount for address into ROM

architecture sample_64 of sine_wave is
  
  --------------------------------------------------------------
  
  constant sine_waveform_map_64 : word_vector( 0 to 63 ) :=
    (
     x"0000", x"0C8C", x"18F9", x"2528", x"30FB", x"3C56", x"471C", x"5133",
     x"5A82", x"62F1", x"6A6D", x"70E2", x"7641", x"7A7C", x"7D89", x"7F61",
     x"7FFF", x"7F61", x"7D89", x"7A7C", x"7641", x"70E2", x"6A6D", x"62F1",
     x"5A82", x"5133", x"471C", x"3C56", x"30FB", x"2528", x"18F8", x"0C8C", 
     x"0000", x"F373", x"E706", x"DAD7", x"CF03", x"C3A9", x"B113", x"AECC",
     x"A57D", x"9D0E", x"9592", x"8F1D", x"89BE", x"8583", x"8276", x"809E",
     x"8000", x"809E", x"8276", x"8583", x"89BE", x"8F1D", x"9592", x"9D0E",
     x"A57D", x"AECC", x"B8E3", x"C3A9", x"CF04", x"DAD7", x"E707", x"F373" );
  
  --------------------------------------------------------------

  signal address : unsigned( 8 downto 0 );
  
  --------------------------------------------------------------

begin

  process begin
    wait until rising_edge(clk);
    address <= address + freq_scale + 1;
  end process;

  o_data <= sine_waveform_map_64( to_integer( address( 8 downto 3 ) ) )
            sra num_bits_mantissa;

end architecture;  

------------------------------------------------------------------------
-- white noise
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fir_synth_pkg.all;


entity white_noise is
  generic (
    use_clock_50 : boolean
  );
  port (
    clk       : in std_logic;
    o_data    : out word
  );
end entity;

------------------------------------------------------------------------

architecture main of white_noise is
  
  --------------------------------------------------------------
  
  constant noise_waveform_map : word_vector( 0 to 1023 ) :=
  (
    x"1E00", x"1F00", x"3000", x"1000", x"C200", x"AB00", x"9900",
    x"5D00", x"4600", x"C700", x"8500", x"2600", x"5700", x"2500",
    x"CD00", x"3D00", x"4A00", x"7900", x"2C00", x"1500", x"9000",
    x"4A00", x"A900", x"3F00", x"DA00", x"0B00", x"AD00", x"F200",
    x"B500", x"F500", x"6400", x"AC00", x"2800", x"FB00", x"6500",
    x"DC00", x"D000", x"1000", x"FF00", x"9200", x"E900", x"A600",
    x"DF00", x"4500", x"2F00", x"B200", x"2300", x"2300", x"FD00",
    x"FA00", x"9200", x"0B00", x"8400", x"F000", x"2500", x"A700",
    x"A300", x"F100", x"6F00", x"B700", x"C400", x"9A00", x"5700",
    x"4800", x"2B00", x"BD00", x"0A00", x"5500", x"AB00", x"2900",
    x"3E00", x"9600", x"7F00", x"4D00", x"BD00", x"0400", x"7500",
    x"BE00", x"3F00", x"9D00", x"9200", x"E800", x"9400", x"1C00",
    x"A200", x"EE00", x"4000", x"C400", x"F600", x"1700", x"3B00",
    x"BD00", x"6400", x"6E00", x"3D00", x"D300", x"3900", x"8E00",
    x"7E00", x"CB00", x"4200", x"1C00", x"5800", x"3400", x"9800",
    x"0E00", x"A400", x"D700", x"5700", x"2C00", x"4B00", x"B100",
    x"DA00", x"E600", x"EB00", x"A800", x"BF00", x"FE00", x"F200",
    x"CA00", x"3E00", x"1100", x"2800", x"6500", x"1400", x"8A00",
    x"FA00", x"B000", x"9500", x"FB00", x"8200", x"5F00", x"1B00",
    x"7600", x"AB00", x"DC00", x"7500", x"DF00", x"5100", x"7500",
    x"8000", x"C500", x"D900", x"4700", x"8E00", x"CA00", x"1600",
    x"2400", x"C400", x"2500", x"EE00", x"4900", x"1F00", x"3A00",
    x"A000", x"2900", x"3B00", x"E400", x"1900", x"0C00", x"8C00",
    x"6200", x"4100", x"D100", x"3400", x"8100", x"9900", x"A400",
    x"1200", x"0700", x"2F00", x"DB00", x"4000", x"DB00", x"2C00",
    x"D000", x"9D00", x"0500", x"0400", x"0600", x"9200", x"0000",
    x"9A00", x"4B00", x"BA00", x"6C00", x"5300", x"3900", x"8900",
    x"A500", x"6400", x"C800", x"B100", x"4700", x"6B00", x"4A00",
    x"5200", x"2F00", x"8F00", x"8C00", x"B600", x"F400", x"3400",
    x"6A00", x"AD00", x"6A00", x"9300", x"A400", x"3F00", x"2F00",
    x"2A00", x"2B00", x"D300", x"D600", x"6700", x"C200", x"7900",
    x"AA00", x"7900", x"2B00", x"7C00", x"9B00", x"AC00", x"B200",
    x"E000", x"5600", x"3C00", x"5C00", x"0100", x"1800", x"0000",
    x"7800", x"ED00", x"3D00", x"DC00", x"EE00", x"A500", x"1500",
    x"6300", x"0200", x"F300", x"0900", x"8700", x"D700", x"F600",
    x"9400", x"CA00", x"8700", x"0F00", x"1F00", x"D300", x"FE00",
    x"5500", x"3F00", x"CB00", x"7E00", x"3D00", x"6500", x"7700",
    x"FF00", x"9700", x"7F00", x"6600", x"3700", x"8F00", x"A100",
    x"2A00", x"9A00", x"D100", x"2900", x"F800", x"1200", x"8300",
    x"7B00", x"A100", x"B900", x"3600", x"CE00", x"4400", x"5D00",
    x"7400", x"1C00", x"A800", x"1900", x"1F00", x"B000", x"A100",
    x"C700", x"3300", x"6F00", x"6400", x"9400", x"3000", x"4E00",
    x"4600", x"7E00", x"B900", x"0600", x"AC00", x"0900", x"9E00",
    x"9900", x"B900", x"E500", x"FD00", x"9600", x"8700", x"E400",
    x"9100", x"C400", x"5C00", x"EE00", x"EB00", x"1C00", x"CB00",
    x"4C00", x"AC00", x"B500", x"1700", x"1200", x"7700", x"9A00",
    x"D700", x"E500", x"B100", x"1400", x"2A00", x"ED00", x"D000",
    x"7B00", x"7500", x"3E00", x"4300", x"0000", x"1200", x"7300",
    x"B900", x"9300", x"CE00", x"D700", x"D200", x"5A00", x"A100",
    x"CC00", x"FE00", x"C200", x"9200", x"CE00", x"9900", x"BE00",
    x"2100", x"CB00", x"0300", x"3100", x"2B00", x"2300", x"C600",
    x"0D00", x"A500", x"0900", x"8200", x"3500", x"2100", x"A400",
    x"C000", x"A100", x"7A00", x"9C00", x"5800", x"D200", x"9600",
    x"7600", x"8A00", x"1F00", x"AB00", x"7100", x"7E00", x"D900",
    x"DD00", x"3D00", x"4800", x"E300", x"B500", x"4600", x"1D00",
    x"AA00", x"4000", x"E600", x"E500", x"1A00", x"5400", x"4000",
    x"C600", x"9500", x"D600", x"0E00", x"DB00", x"6A00", x"6C00",
    x"2700", x"C000", x"DC00", x"8400", x"0E00", x"1000", x"4600",
    x"1800", x"3F00", x"8500", x"5300", x"1600", x"A100", x"E200",
    x"E400", x"D700", x"BE00", x"5000", x"A100", x"8200", x"3000",
    x"4B00", x"C400", x"DA00", x"E800", x"D900", x"2000", x"4000",
    x"B700", x"2200", x"EC00", x"6F00", x"C600", x"2200", x"6100",
    x"C700", x"5400", x"8600", x"AF00", x"9000", x"8100", x"7500",
    x"4B00", x"2D00", x"6800", x"5C00", x"2700", x"8F00", x"5900",
    x"7000", x"DA00", x"E400", x"6900", x"FC00", x"3D00", x"E100",
    x"3F00", x"4000", x"8500", x"9200", x"4300", x"EE00", x"6300",
    x"1000", x"0F00", x"F600", x"3A00", x"1500", x"6500", x"D400",
    x"DF00", x"C300", x"6700", x"F700", x"0300", x"9A00", x"6B00",
    x"7000", x"BC00", x"EE00", x"2100", x"9700", x"4300", x"DE00",
    x"6400", x"C400", x"5F00", x"1D00", x"6C00", x"CB00", x"9A00",
    x"8900", x"BC00", x"5B00", x"B400", x"E400", x"8400", x"FB00",
    x"6700", x"AC00", x"C700", x"AD00", x"0300", x"6800", x"0D00",
    x"FF00", x"E500", x"5C00", x"E700", x"A100", x"5B00", x"0E00",
    x"0C00", x"2C00", x"EF00", x"7400", x"5800", x"3A00", x"AA00",
    x"4A00", x"7C00", x"8D00", x"5F00", x"6900", x"9500", x"5200",
    x"6A00", x"8800", x"8B00", x"3900", x"1100", x"5300", x"6600",
    x"8700", x"F000", x"3D00", x"7500", x"C400", x"8500", x"FE00",
    x"8500", x"3A00", x"6400", x"1000", x"F400", x"D800", x"1B00",
    x"2F00", x"E700", x"B900", x"4A00", x"2A00", x"6500", x"E600",
    x"F900", x"0000", x"AA00", x"8100", x"B800", x"A300", x"7600",
    x"0000", x"8900", x"5800", x"9800", x"A400", x"2500", x"0B00",
    x"8700", x"CA00", x"9D00", x"8E00", x"5200", x"4D00", x"DE00",
    x"1E00", x"9F00", x"9000", x"2C00", x"2300", x"1B00", x"6700",
    x"0E00", x"8A00", x"0600", x"7C00", x"B700", x"A000", x"3E00",
    x"5F00", x"7900", x"E000", x"7C00", x"E900", x"4700", x"9100",
    x"1900", x"0D00", x"C700", x"A100", x"1800", x"DA00", x"0F00",
    x"A500", x"C600", x"B600", x"7800", x"6800", x"B800", x"9000",
    x"AE00", x"E900", x"6300", x"3000", x"7100", x"3B00", x"2400",
    x"3B00", x"1000", x"2600", x"FB00", x"2B00", x"3200", x"F600",
    x"BD00", x"D100", x"EB00", x"5D00", x"0F00", x"9300", x"A400",
    x"D500", x"DF00", x"0600", x"E600", x"6400", x"C100", x"1600",
    x"8A00", x"2900", x"D400", x"5B00", x"5700", x"A400", x"9A00",
    x"C900", x"9400", x"1B00", x"6E00", x"5A00", x"A200", x"F700",
    x"F400", x"EB00", x"0E00", x"A100", x"4200", x"E200", x"3E00",
    x"A200", x"0600", x"CE00", x"3100", x"8800", x"8100", x"A700",
    x"5500", x"7200", x"8800", x"DA00", x"1400", x"A000", x"6E00",
    x"BE00", x"0200", x"FF00", x"FF00", x"AE00", x"4200", x"0B00",
    x"7900", x"5600", x"3400", x"FF00", x"A600", x"6E00", x"E000",
    x"A800", x"FA00", x"8C00", x"3200", x"CE00", x"F500", x"2000",
    x"8B00", x"A100", x"8600", x"6000", x"B600", x"0100", x"CC00",
    x"3300", x"BE00", x"1900", x"EA00", x"CC00", x"B300", x"2A00",
    x"3D00", x"2600", x"EA00", x"F800", x"C400", x"F600", x"B400",
    x"B300", x"F200", x"4C00", x"2500", x"D700", x"BE00", x"8500",
    x"DD00", x"D700", x"3700", x"B100", x"7800", x"0E00", x"6100",
    x"1A00", x"8C00", x"C800", x"A400", x"1D00", x"D600", x"E300",
    x"9500", x"E100", x"9900", x"E200", x"6500", x"3C00", x"A800",
    x"D400", x"B500", x"4700", x"3A00", x"0D00", x"2400", x"E300",
    x"FF00", x"0300", x"4D00", x"CF00", x"8200", x"3D00", x"9200",
    x"7100", x"6600", x"C800", x"6B00", x"0800", x"8100", x"0800",
    x"8D00", x"5A00", x"5500", x"5900", x"A200", x"A100", x"0600",
    x"6700", x"EE00", x"C500", x"3C00", x"9B00", x"9A00", x"9F00",
    x"0300", x"9400", x"EF00", x"5900", x"3A00", x"0A00", x"4F00",
    x"B000", x"8800", x"0500", x"3200", x"1B00", x"6B00", x"CD00",
    x"E800", x"A200", x"6700", x"8800", x"7000", x"7500", x"D900",
    x"DC00", x"2E00", x"F700", x"7900", x"8500", x"BC00", x"5F00",
    x"1000", x"5000", x"A900", x"9B00", x"7600", x"5300", x"6E00",
    x"9E00", x"4A00", x"D200", x"5600", x"B800", x"7F00", x"BD00",
    x"AE00", x"2D00", x"4300", x"2500", x"0000", x"AA00", x"3A00",
    x"9A00", x"9C00", x"C100", x"AC00", x"D400", x"3D00", x"1800",
    x"9400", x"8D00", x"1500", x"6D00", x"3600", x"FF00", x"0000",
    x"2300", x"2200", x"DE00", x"2400", x"6800", x"4A00", x"4700",
    x"D800", x"C000", x"2200", x"7C00", x"0200", x"F300", x"5500",
    x"DF00", x"C700", x"2C00", x"1D00", x"1600", x"C700", x"5900",
    x"BB00", x"B400", x"BA00", x"7F00", x"2600", x"5A00", x"AD00",
    x"1E00", x"6700", x"BA00", x"A400", x"6200", x"BD00", x"5200",
    x"FC00", x"3700", x"FE00", x"6000", x"3600", x"E700", x"4F00",
    x"E000", x"9300", x"7B00", x"AE00", x"1300", x"3500", x"7700",
    x"5800", x"5C00", x"1100", x"2000", x"9F00", x"F400", x"7A00",
    x"F000", x"2100", x"4F00", x"9B00", x"6400", x"0500", x"9E00",
    x"8500", x"D000", x"2600", x"5400", x"4900", x"5100", x"D200",
    x"1800", x"B700", x"9500", x"1100", x"1000", x"2E00", x"9F00",
    x"0300", x"E000", x"2E00", x"2700", x"6000", x"5400", x"0000",
    x"C000", x"9700", x"1600", x"3A00", x"7600", x"A400", x"5500",
    x"6000", x"FE00", x"1900", x"CD00", x"7800", x"2A00", x"6300",
    x"0E00", x"C700", x"C400", x"D800", x"7600", x"8D00", x"7900",
    x"9600", x"B900", x"0900", x"0000", x"B300", x"6C00", x"7B00",
    x"1D00", x"CE00", x"6E00", x"8400", x"AD00", x"8B00", x"A300",
    x"9C00", x"6700", x"F300", x"DF00", x"E700", x"7100", x"5500",
    x"7300", x"3B00", x"7600", x"A300", x"3700", x"9700", x"6800",
    x"CD00", x"8700", x"CF00", x"8D00", x"3800", x"1300", x"BF00",
    x"0700", x"C200", x"E800", x"CE00", x"8200", x"6600", x"A400",
    x"F400", x"2000", x"0A00", x"2D00", x"2D00", x"5D00", x"7900",
    x"E800", x"7F00", x"0800", x"1300", x"C300", x"7500", x"0200",
    x"3D00", x"0900", x"4600", x"DC00", x"1400", x"6000", x"7C00",
    x"0E00", x"7800", x"DB00", x"5700", x"E400", x"DE00", x"8B00",
    x"C100", x"CA00", x"1100", x"7400", x"0F00", x"1E00", x"4C00",
    x"4C00", x"6100"
  );

  --------------------------------------------------------------

  signal clock_count       : unsigned(20 downto 0);

  signal address           : unsigned( 9 downto 0 );
  
  --------------------------------------------------------------
  
begin

  -- White noise data has 1024 samples
  -- Lowest audible frequency should have one complete wave
  -- in the 1024 samples.
  --
  -- With a 50MHz clock signal, if we divide down
  -- by 2048, the 1024 samples would represent an approx 25 Hz wave.
  --
  -- With data_clock from audio_dac, just use the data clock directly.
  --

  clock_50_yes : if use_clock_50 generate
    process begin
      wait until rising_edge(clk);
      clock_count <= clock_count + 1;
    end process;
    address       <= clock_count( 20 downto 11 );
  end generate;

  clock_50_no : if not use_clock_50 generate
    process begin
      wait until rising_edge(clk);
      address     <= address + 1;
    end process;
  end generate;

  process begin
    wait until rising_edge(clk);
    o_data      <= noise_waveform_map( to_integer ( address ) )
                   sra num_bits_mantissa;
  end process;
  
end architecture;  

------------------------------------------------------------------------
-- audio_pll
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity audio_pll is
  port (
    inclk0 : in std_logic;
    c0, c1 : out std_logic
  );
end entity;

architecture main of audio_pll is

  signal sub_wire0 : std_logic_vector( 5 downto 0 );
  signal sub_wire1 : std_logic_vector( 0 downto 0 );
  signal sub_wire2 : std_logic_vector( 1 downto 1 );
  signal sub_wire3 : std_logic;
  signal sub_wire4 : std_logic_vector( 1 downto 0 );
  signal sub_wire5 : std_logic_vector( 0 downto 0 );
  
begin

  sub_wire5 <= b"0";
  sub_wire1 <= sub_wire0( 0 downto 0 );
  sub_wire2 <= sub_wire0( 1 downto 1 );
  c0        <= sub_wire1(0);
  c1        <= sub_wire2(1);
  sub_wire3 <= inclk0;
  sub_wire4 <= sub_wire5 & sub_wire3;

  altpll : component altera_mf.altera_mf_components.altpll
    generic map (
        clk1_divide_by         => 3
      , clk1_phase_shift       => "0"                 
      , clk0_duty_cycle        => 50                   
      , lpm_type               => "altpll"                    
      , clk0_multiply_by       => 14                  
      , inclk0_input_frequency => 37037         
      , clk0_divide_by         => 15                    
      , clk1_duty_cycle        => 50                   
      , pll_type               => "FAST"                      
      , clk1_multiply_by       => 2                   
      , intended_device_family => "Cyclone II"  
      , operation_mode         => "NORMAL"              
      , compensate_clock       => "CLK0"               
      , clk0_phase_shift       => "0"
    )
    port map (
        inclk => sub_wire4
      , clk   => sub_wire0
    );
        
end architecture;  
    
------------------------------------------------------------------------
-- audio_dac
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity audio_dac is
  port (
    ----------------------------------------------------
    -- audio side
    o_aud_bck,
    o_aud_lrck    : out std_logic;
    ----------------------------------------------------
    -- control signals
    clock_27      : in std_logic;
    reset_n       : in std_logic;
    clock_18_4    : out std_logic
    ----------------------------------------------------
  );
end entity;

architecture main of audio_dac is

  constant ref_clk : natural := 18432000;  -- 18.432 MHz
  constant sample_rate : natural := 48000;  -- 48 kHz
  constant data_width  : natural := 16;
  constant channel_num : natural := 2;

  constant sin_sample_data : natural := 32;

  signal bck_div : unsigned( 3 downto 0 );
  signal lrck_1x_div : unsigned( 8 downto 0 );

  signal lrck_1x
       , x_clock_18_4
       , aud_bck
       : std_logic;
  
begin  

  p1 : entity work.audio_pll
    port map (
        inclk0 => clock_27
      , c1     => x_clock_18_4
    );

  process begin
    wait until rising_edge( x_clock_18_4 );
    if reset_n = '0' then
      bck_div <= to_unsigned( 0, 4);
      aud_bck <= '0';
    else
      if bck_div
         >=
        (ref_clk / (sample_rate * data_width * channel_num * 2) ) - 1
      then
        bck_div <= to_unsigned( 0, 4 );
        aud_bck <= not aud_bck;
      else
        bck_div <= bck_div + 1;
      end if;
    end if;
  end process;

  process begin
    wait until rising_edge( x_clock_18_4 );
    if reset_n = '0' then
      lrck_1x_div <= to_unsigned( 0, 9 );
      lrck_1x     <= '0';
    else
      if lrck_1x_div >= ref_clk / (sample_rate*2) - 1 then
        lrck_1x_div <= to_unsigned( 0, 9 );
        lrck_1x     <= not lrck_1x;
      else
        lrck_1x_div <= lrck_1x_div + 1;
      end if;
    end if;
  end process;

  clock_18_4 <= x_clock_18_4;
  o_aud_bck  <= aud_bck;
  o_aud_lrck <= lrck_1x;
  
end architecture;  

------------------------------------------------------------------------
-- derived from I2C_Controller.v by Terasic
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_ctrl is
  port (
    ----------------------------------------------------
    clock,
    reset        : in    std_logic;
    ----------------------------------------------------
    i2c_sclk     : out   std_logic;
    i2c_sdat     : inout std_logic;
    start_xfr    : in    std_logic;
    finish_xfr   : out   std_logic;
    ack          : out   std_logic;
    ----------------------------------------------------
    i2c_data     : in std_logic_vector( 23 downto 0 )
    ----------------------------------------------------
  );
end entity;

architecture main of i2c_ctrl is
  signal sdo
       , sclk
       , init_phase
       , ack1
       , ack2
       , ack3
       : std_logic;
  
  signal sd : std_logic_vector( 23 downto 0 );
  signal sd_counter : unsigned( 5 downto 0 );
  
begin

  init_phase <=   '1' when (sd_counter >= 4) and (sd_counter <= 30)
             else '0';
  
  i2c_sclk   <=   sclk or not clock when init_phase = '1'
             else sclk;

  i2c_sdat   <=   'Z' when sdo = '1'
             else '0';

  process begin
    wait until rising_edge(clock);
    if reset = '0' then
      sd_counter <= (others => '1');
    else
      if start_xfr = '1' then
        sd_counter <= (others => '0');
      elsif sd_counter /= to_unsigned( 63, 6 ) then
        sd_counter <= sd_counter + 1;
      end if;
    end if;
  end process;

  process begin
    wait until rising_edge(clock);
    if reset = '0' then
      sclk       <= '1';
      sdo       <= '1';
      ack1       <= '0';
      ack2       <= '0';
      ack3       <= '0';
      finish_xfr <= '0';
    else
      if sd_counter = to_unsigned(0, 6) then
          sclk       <= '1';
          sdo        <= '1';
          ack1       <= '0';
          ack2       <= '0';
          ack3       <= '0';
          finish_xfr <= '0';
      elsif sd_counter = to_unsigned(1, 6) then
          sd <= i2c_data;
          sdo <= '0';
      elsif sd_counter = to_unsigned(2, 6) then
          sclk <= '0';
      ------------------------------------------
      -- slave address
      elsif sd_counter <= to_unsigned( 10, 6 ) then
        sdo <= sd( to_integer( 26 - sd_counter ) );
      elsif sd_counter = to_unsigned( 11, 6 ) then
        sdo <= '1';                    -- ack
      ------------------------------------------
      -- sub address
      elsif sd_counter = to_unsigned( 12, 6 ) then
        ack1 <= i2c_sdat;
        sdo <= sd( to_integer( 27 - sd_counter ) );
      elsif sd_counter <= to_unsigned( 19, 6 ) then
        sdo <= sd( to_integer( 27 - sd_counter ) );
      elsif sd_counter = to_unsigned( 20, 6 ) then
        sdo <= '1';                    -- ack
      ------------------------------------------
      -- data
      elsif sd_counter = to_unsigned( 21, 6 ) then
        ack2 <= i2c_sdat;
        sdo <= sd( to_integer( 28 - sd_counter ) );
      elsif sd_counter <= to_unsigned( 28, 6 ) then
        sdo <= sd( to_integer( 28 - sd_counter ) );
      elsif sd_counter = to_unsigned( 29, 6 ) then
        sdo <= '1';                    -- ack
      ------------------------------------------
      -- finish the transfer
      elsif sd_counter = to_unsigned( 30, 6 ) then
        sdo <= '0';
        sclk <= '0';
        ack3 <= i2c_sdat;
      elsif sd_counter = to_unsigned( 31, 6 ) then
        sclk <= '1';
      elsif sd_counter = to_unsigned( 32, 6 ) then
        sdo <= '1';
        finish_xfr <= '1';
      end if;
      ------------------------------------------
    end if;
  end process;

  ack <= ack1 or ack2 or ack3;

end architecture;
      

------------------------------------------------------------------------
-- I2C configuration for audio
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity i2c_av_config is
  port (
    ----------------------------------------------------
    -- host side
    clk : in std_logic;
    ----------------------------------------------------
    -- I2C side
    i2c_sclk : out   std_logic;
    i2c_sdat : inout std_logic
    ----------------------------------------------------
  );
end entity;

architecture main of i2c_av_config is

  constant clk_freq : natural := 50000000;  -- 50 MHz
  constant i2c_freq : natural := 20000;     -- 20 kHz

  -- lut data number
  constant lut_size : natural := 10;    -- EP: used to be 50

  -- audio data index
  constant set_lin_l	  : unsigned( 5 downto 0 ) := to_unsigned(  0, 6 );
  constant set_lin_r	  : unsigned( 5 downto 0 ) := to_unsigned(  1, 6 );
  constant set_head_l	  : unsigned( 5 downto 0 ) := to_unsigned(  2, 6 );
  constant set_head_r	  : unsigned( 5 downto 0 ) := to_unsigned(  3, 6 );
  constant a_path_ctrl	  : unsigned( 5 downto 0 ) := to_unsigned(  4, 6 );
  constant d_path_ctrl	  : unsigned( 5 downto 0 ) := to_unsigned(  5, 6 );
  constant power_on	  : unsigned( 5 downto 0 ) := to_unsigned(  6, 6 );
  constant set_format	  : unsigned( 5 downto 0 ) := to_unsigned(  7, 6 );
  constant sample_ctrl	  : unsigned( 5 downto 0 ) := to_unsigned(  8, 6 );
  constant set_active	  : unsigned( 5 downto 0 ) := to_unsigned(  9, 6 );
  constant set_video      : unsigned( 5 downto 0 ) := to_unsigned( 10, 6 );

  signal reset_n          : std_logic;
  
  signal m_setup_st       : unsigned( 3 downto 0 );
  
  signal lut_index        : unsigned(  5 downto 0 );
  signal lut_data         : unsigned( 15 downto 0 );

  signal m_i2c_clk_div    : unsigned( 15 downto 0 );
  signal m_i2c_data       : std_logic_vector( 23 downto 0 );

  signal m_i2c_ctrl_clk
       , m_i2c_start_xfr
       , m_i2c_finish_xfr
       , m_i2c_ack
       : std_logic;
  
  signal cont             : unsigned( 15 downto 0 );
  
begin

  process begin
    wait until rising_edge(clk);
    if cont /= to_unsigned( 65535, 16 ) then
      cont    <= cont + 1;
      reset_n <= '0';
    else
      reset_n <= '1';
    end if;
  end process;

  process begin
    wait until rising_edge(clk);
    if reset_n = '0' then
      m_i2c_ctrl_clk <= '0';
      m_i2c_clk_div  <= to_unsigned( 0, 16 );
    else
      if m_i2c_clk_div < clk_freq / i2c_freq then
        m_i2c_clk_div <= m_i2c_clk_div + 1;
      else
        m_i2c_clk_div <= to_unsigned( 0, 16 );
        m_i2c_ctrl_clk <= not m_i2c_ctrl_clk;
      end if;
    end if;
  end process;

  u0 : entity work.i2c_ctrl(main) port map (
      clock      => m_i2c_ctrl_clk
    , i2c_sclk   => i2c_sclk
    , i2c_sdat   => i2c_sdat
    , i2c_data   => m_i2c_data
    , start_xfr  => m_i2c_start_xfr
    , finish_xfr => m_i2c_finish_xfr
    , ack        => m_i2c_ack
    , reset      => reset_n
  );

  process begin
    wait until rising_edge(clk);
    if reset_n = '0' then
      lut_index  <= to_unsigned( 0, 6 );
      m_setup_st <= to_unsigned( 0, 4 );
      m_i2c_start_xfr <= '0';
    elsif lut_index < lut_size then
      case m_setup_st is
        when x"0" =>
          if lut_index < set_video then
            m_i2c_data <= std_logic_vector( x"34" & lut_data );
          else
            m_i2c_data <= std_logic_vector( x"40" & lut_data );
            m_i2c_start_xfr <= '1';
            m_setup_st      <= to_unsigned( 1, 4 );
          end if;
        when x"1" =>
          if m_i2c_finish_xfr = '1' then
            if m_i2c_ack = '0' then
              m_setup_st <= to_unsigned( 2, 4 );
            else
              m_setup_st <= to_unsigned( 0, 4 );
              m_i2c_start_xfr <= '0';
            end if;
          end if;
        when x"2" =>
          lut_index <= lut_index + 1;
          m_setup_st <= to_unsigned( 0, 4 );
        when others =>
          null;
      end case;
    end if;
  end process;

  with lut_index select
    lut_data <= x"001a" when set_lin_l	
              , x"021a" when set_lin_r	
              , x"047b" when set_head_l	
              , x"067b" when set_head_r	
              , x"08f8" when a_path_ctrl	
              , x"0a06" when d_path_ctrl	
              , x"0c00" when power_on	
              , x"0e01" when set_format	
              , x"1002" when sample_ctrl  -- 8kHz sample rate
              , x"1201" when set_active	
              , x"0000" when others;
    
    --        , x"100c" when sample_ctrl 48 kHz default value
    --        , x"1000" when sample_ctrl 48 kHz w/ 12.288MHz m-clock
  
end architecture;    
    
