------------------------------------------------------------------------
-- lab3 test bench
------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.lab3_unsynth_pkg.all;

entity lab3_tb is
  generic ( test_num     : integer   := 1;
            result_file  : string    := "sim_result.txt"
          );
end lab3_tb;

architecture main of lab3_tb is

  --------------------------------------------------------------
  -- clock cycle

  constant period  : time := 20 ns;

  --------------------------------------------------------------
  -- name of test file

  constant test_name   : string     := "test"& integer'image(test_num);
  constant test_file   : string     := "tests/"& test_name &".txt";

  --------------------------------------------------------------
  -- number of invalid input data between valid data
  
  constant bubbles      : natural    := 3;

  --------------------------------------------------------------
  -- upper and lower bounds on indices for input data
  
  constant row_min      : natural    := 0;
  constant row_max      : natural    := input_height - 1;
  
  constant col_min      : natural    := 0;
  constant col_max      : natural    := input_width - 1;
  
  --------------------------------------------------------------
  -- signals to interface to lab3.vhd
  
  signal clock          : std_logic;
  signal reset          : std_logic;
  
  signal in_valid       : std_logic;
  
  signal in_input        : std_logic_vector(7 downto 0); 
  signal input           : unsigned(7 downto 0); 
  signal out_output      : std_logic_vector(7 downto 0);                      
  
  --------------------------------------------------------------
  -- 2-d array for input data
  
  signal input_matrix : input_matrix_ty;
  
  --------------------------------------------------------------

 
begin

    ----------------------------------------------------
    -- use circuit
    
    uut: entity WORK.lab3 port map
      (i_clock    => clock,
       i_valid    => in_valid,
       i_input    => std_logic_vector(input),
       i_reset    => reset,
       o_output   => out_output
      );

       in_input  <= std_logic_vector(input);

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
        wait for 2 * period;
        reset <= '0';
        wait;
    end process;

    ----------------------------------------------------
    -- read input data from file, then send to circuit

    process
    begin
      in_valid <= '0';
      input_matrix <= read_input( test_file );
      wait until rising_edge(clock);
      wait until rising_edge(clock);
      for row_idx in row_min to row_max loop
        for col_idx in col_min to col_max loop
          for delay_count in 1 to bubbles loop
            wait until rising_edge(clock);
          end loop;
          wait for period/4;
          in_valid <= '1';
          input    <= input_matrix(row_idx, col_idx);
          wait for period;
          in_valid <= '0';
          input    <= to_unsigned(0,8);
        end loop;
      end loop;
      wait;
    end process;

    ----------------------------------------------------
    -- wait until done, then print output value

    process
      variable spec_val, impl_val : integer;
    begin
      wait; -- delete this line to enable execution of remainder of process
      wait for (10 + input_height*input_width*(1+bubbles)) * period;
      impl_val := to_integer(unsigned(out_output));
      case test_num is
        when 1       => spec_val := 188;
        when 2       => spec_val := 183;
        when 3       => spec_val := 196;
        when 4       => spec_val := 178;
        when 5       => spec_val := 201;
        when others  => spec_val := -1;
      end case;
      -- if test_num = 1, then overwrite result_file, otherwise append
      if  impl_val = spec_val then
        if test_num = 1 then 
          write_file( result_file, test_name &" PASS" );
        else
          append_file( result_file, test_name &" PASS" );
        end if;
        report( test_name &" PASS" );
      else
        if test_num = 1 then 
          write_file( result_file, test_name &" FAIL" );
        else
          append_file( result_file, test_name &" PASS" );
        end if;
        report("    "& integer'image(192));
        report( test_name &" FAIL impl="& integer'image(impl_val)
                              &"; spec="& integer'image(spec_val));
      end if;
      wait;
    end process;
    
end main;

