------------------------------------------------------------------------
-- constants and types for lab3
------------------------------------------------------------------------

------------------------------------------------------------------------
-- package declaration
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

package lab3_unsynth_pkg is

  --------------------------------------------------------------
  -- types

  constant input_height : natural := 16;
  constant input_width  : natural := 16;

  type input_matrix_ty is
    array( 0 to input_height-1, 0 to input_width - 1 ) of unsigned(7 downto 0);
  
  --------------------------------------------------------------
  -- read input from a file
  
  impure function read_input( filename : string ) return input_matrix_ty;
  
  procedure write_file  ( filename : in string; msg : in string);
  procedure append_file ( filename : in string; msg : in string);
  procedure append_file ( filename : in string; msg : in integer);

end lab3_unsynth_pkg;


------------------------------------------------------------------------
-- package body
------------------------------------------------------------------------

package body lab3_unsynth_pkg is
  
  --------------------------------------------------------------
  -- read input from a file
  
  impure function read_input ( filename : string ) return input_matrix_ty is
    file rd_file      : text open read_mode is filename;
    variable textline : line;
    variable rd_ok    : boolean;
    variable input    : integer;
    variable row_min,
             row_max,
             col_min,
             col_max,
             row_idx,
             col_idx  : natural;
    variable input_matrix : input_matrix_ty;
  begin
    row_min:= input_matrix_ty'low(1);
    row_max:= input_matrix_ty'high(1);
    col_min:= input_matrix_ty'low(2);
    col_max:= input_matrix_ty'high(2);
   
    for row_idx in row_min to row_max loop
      if endfile(rd_file) then
        -- report ("ERROR: premature end of file at ("&
        --   to_string(row_idx) &","& to_string(col_idx) &")");
        input_matrix(row_idx, col_idx) := (to_unsigned(input,8));
      else
        readline(rd_file, textline);
        for col_idx in col_min to  col_max loop
          read( textline, input, rd_ok);
          if rd_ok then 
            input_matrix(row_idx, col_idx) := (to_unsigned(input,8));
          else
            -- report ("ERROR: premature end of file at ("&
            --           to_string(row_idx) &","& to_string(col_idx) &")");
            input_matrix(row_idx, col_idx) := (to_unsigned(input,8));
          end if;
        end loop;
      end if;
    end loop;
    return input_matrix;
  end read_input;
  
  --------------------------------------------------------------
  -- write a string to a file
  
  procedure write_file ( filename : in string; msg : in string) is
    file wr_file       : text open write_mode is filename;
    variable textline  : line;
  begin
    write( textline, msg );
    writeline(wr_file, textline);
  end write_file;

  --------------------------------------------------------------
  -- append a string to a file
  
  procedure append_file ( filename : in string; msg : in string) is
    file wr_file       : text open append_mode is filename;
    variable textline  : line;
  begin
    write( textline, msg );
    writeline(wr_file, textline);
  end append_file;

  --------------------------------------------------------------
  -- append an integer to a file
  
  procedure append_file ( filename : in string; msg : in integer) is
    file wr_file       : text open append_mode is filename;
    variable textline  : line;
  begin
    write( textline, msg );
    writeline(wr_file, textline);
  end append_file;

end lab3_unsynth_pkg;
