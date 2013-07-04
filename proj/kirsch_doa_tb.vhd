-------------------------------------------------------------------------------
-- kirsch_tb.vhd
-- This testbench reads a txt file and stores the values into a mem[m n]
-- array.  It then passes the data to the main code.
-- Afterward it receives the results and stores them in two text files
-- Copyright(c) 2005, University of Waterloo, F. Khalvati, M.Aagaard
-------------------------------------------------------------------------------


------------------------------------------------------------------------
-- test bench
------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library STD;
use std.textio.all;

use work.kirsch_synth_pkg.all;
use work.kirsch_unsynth_pkg.all;

entity kirsch_tb is
  generic ( test_num     : integer   := 1
          );
end kirsch_tb;

architecture main of kirsch_tb is

  --------------------------------------------------------------
  -- names of files

  constant image_file      : string     := "tests/test1.txt";
  constant result_file     : string     := "doa_test.txt";
  constant latency_file    : string     := "latency.txt";

  --------------------------------------------------------------
  -- clock cycle

  constant period  : time := 20 ns;

  --------------------------------------------------------------
  -- number of invalid input data between valid data
  
  constant bubbles      : natural    := 7;

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
  
  --------------------------------------------------------------
  -- for dead or alive test
  
  constant num_doa_pixels       : natural := 2*(row_max - row_min + 1);

  constant TEST_PASSED   : string :=
    "SUMMARY: basic DOA functionality test PASS";
  
  constant TEST_FAILED   : string :=
    "SUMMARY: basic DOA functionality test FAIL";

  signal done_sending : boolean;
  
  -----------------------------------------------------------------
  -- write dead-or-alive test result to a file

  procedure write_result ( filename : in string; test_result: in string) is
    file wr_file       : text open write_mode is filename;
    variable textline  : line;
  begin
    write( textline, test_result );
    writeline(wr_file, textline);
  end write_result;
                       
  --------------------------------------------------------------
  
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
      wait for period/2;
      clock <= '1';
      wait for period/2;
    end process;

    ----------------------------------------------------
    -- reset

    process
    begin
      reset <= '1';
      wait for period*5;
      reset <= '0';
      wait;
    end process;
    
    ----------------------------------------------------
    -- read image data from file, then send first three rows to circuit

    process
    begin
      done_sending <= false;
      in_valid <= '0';
      image    <= read_image( image_file );
      wait until rising_edge(clock);
      wait until (reset = '0');
      wait until rising_edge(clock);
      wait for period/4;
      for row_idx in 0 to 3 loop
        for col_idx in col_min to col_max loop
          wait for bubbles * period;
          in_valid <= '1';
          in_pixel <= image(row_idx, col_idx);
          wait for period;
          in_pixel <= (others => '0');
          in_valid <= '0';
        end loop;
      end loop;
      done_sending <= true;
      wait;
    end process;

    ----------------------------------------------------
    -- check out_valid after done sending pixels

    process begin
      ------------------------------------------
      wait until reset = '1';
      wait until reset = '0';
      wait until done_sending or out_valid = '1';
      ------------------------------------------
      if out_valid = '1' then
        write_result( result_file, TEST_PASSED);
      else 
        write_result( result_file, TEST_FAILED);
      end if;   
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
      write_result( latency_file, "latency is " & integer'image(latency-1) );
      wait;
    end process;

end main;
