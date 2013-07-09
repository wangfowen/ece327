-------------------------------------------------------------------------------
-- kirsch_tb.vhd
-- test bench
-- This testbench reads a txt file and stores the values into a mem[m n]
-- array.  It then passes the data to the main code.
-- Afterward it receives the results and stores them in a .ted file,
-- which contains one line for each pixel:
--  <edge> <dir> <row> <col>
--  
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

use work.kirsch_synth_pkg.all;
use work.file_pkg.all;
use work.kirsch_unsynth_pkg.all;

entity kirsch_tb is
  generic (
    test_num      : natural := 1;
    result_suffix : string  := "sim";
    bubbles       : natural := 3;
    period        : real    := 20.0
  );
end kirsch_tb;

architecture main of kirsch_tb is

  --------------------------------------------------------------
  -- names of test file, edge file, and direction file

  constant test_str     : string := integer'image(test_num);
  constant image_name   : string := "tests/test"& test_str &".txt";
  constant result_name  : string := "tests/res"& test_str &"_"& result_suffix;
  constant latency_file : string := "latency.txt";

  --------------------------------------------------------------
  -- clock cycle

  constant clk_period   : time       := period * 1 ns;

  --------------------------------------------------------------
  -- upper and lower bounds on indices for images
  
  constant row_min      : natural    := image_ty'low(1);
  constant row_max      : natural    := image_ty'high(1);
  
  constant col_min      : natural    := image_ty'low(2);
  constant col_max      : natural    := image_ty'high(2);
  
  --------------------------------------------------------------
  -- signals to interface to edge detector
  
  signal clock          : std_logic;
  signal reset          : std_logic;
  
  signal in_valid       : std_logic;
  signal in_pixel       : pixel_ty;
  
  signal out_mode       : mode_ty;
  signal out_row        : unsigned(7 downto 0); 
  signal out_valid      : std_logic;
  signal out_edge       : std_logic;
  signal out_dir        : direction_ty;

  --------------------------------------------------------------
  -- 2-d arrays for images
  
  signal image,                          -- initial image
         edge_image,                     -- image of edges
         dir_image      : image_ty;      -- image of directions
  
  -----------------------------------------------------------------
  
begin

    ----------------------------------------------------
    -- edge detector circuit

    uut: entity work.kirsch port map
      (i_clock              => clock,
       i_valid              => in_valid,
       i_pixel              => std_logic_vector(in_pixel),
       i_reset              => reset,
       o_valid              => out_valid,
       o_edge               => out_edge,
       direction_ty(o_dir)  => out_dir,
       mode_ty(o_mode)      => out_mode,
       unsigned(o_row)      => out_row,
       debug_key            => (others => '0'),
       debug_switch         => (others => '0')
      );

    ----------------------------------------------------
    -- clock

    process
    begin
      clock <= '0';
      wait for clk_period/2;
      clock <= '1';
      wait for clk_period/2;
    end process;

    ----------------------------------------------------
    -- reset

    process
    begin
      reset <= '1';
      for i in 1 to 5 loop
        wait until rising_edge(clock);
      end loop;
      reset <= '0';
      wait;
    end process;
    
    ----------------------------------------------------
    -- read image data from file, then send to circuit

    process
    begin
      in_valid <= '0';
      image    <= read_image( image_name );
      report("XXXXXXXXXXXX reading image from "& image_name);
      wait until rising_edge(clock);
      wait until reset = '0';
      wait until rising_edge(clock);
      wait for clk_period/4;
      for row_idx in row_min to row_max loop
        for col_idx in col_min to col_max loop
          wait for bubbles * clk_period;
          in_valid <= '1';
          in_pixel <= image(row_idx, col_idx);
          wait for clk_period;
          in_pixel <= (others => '0');
          in_valid <= '0';
        end loop;
      end loop;
      report("XXXXXXXXXXXX sent image");
      wait;
    end process;

    ----------------------------------------------------
    -- Receive the output data from circuit.
    -- Store edge data in edge_image and direction data in dir_image.
    -- After done reading image, write edges and directions to files.

    process
      file edge_dir_file : text;
    begin
      --------------------------------------------
      -- delay opening of file so that sim script has opportunity
      -- to overwrite result_name
      --
      wait until rising_edge(clock);
      file_open (edge_dir_file, result_name &".ted" , write_mode );
      --------------------------------------------
      for row_idx in row_min+1 to row_max-1 loop
        for col_idx in col_min+1 to col_max-1 loop
          wait until rising_edge(clock);
          while out_valid /= '1' loop
            wait until rising_edge(clock);
          end loop;
          write_edge_dir( edge_dir_file,
                           out_edge, out_dir, row_idx, col_idx );
        end loop;
      end loop;
      report("XXXXXXXXXXXX got image");
      wait;
    end process;

    ----------------------------------------------------
    -- count latency after done sending pixels

    process
      variable latency : natural := 0;
    begin
      ------------------------------------------
      wait until reset = '1';
      wait until reset = '0';
      for pix_count in 1 to (row_max - row_min + 1) * 2 + 3 loop
        wait until in_valid = '1';
      end loop;
      ------------------------------------------
      latency := 0;
      report "latency begin wait";
      while out_valid /= '1' loop
        wait until rising_edge(clock);
        report "latency waiting";
        latency := latency + 1;
      end loop;
      report "latency = "& integer'image(latency-1);
      write_file( latency_file, "latency is " & integer'image(latency-1) );
      wait;
    end process;

end main;
