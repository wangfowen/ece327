library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;


package file_pkg is
  
  --------------------------------------------------------------
  -- write integers and strings to file
  
  procedure write_file  ( filename : in string; msg : in string);
  procedure write_file  ( filename : in string; msg : in integer);
  procedure append_file ( filename : in string; msg : in string);
  procedure append_file ( filename : in string; msg : in integer);
    
end package;

package body file_pkg is

  --------------------------------------------------------------
  -- open a new file
  
  procedure open_file ( filename : in string )
  is
    file wr_file       : text open write_mode is filename; 
    variable textline  : line;  
  begin
    write( textline, filename);
    writeline(wr_file, textline);
  end;

  --------------------------------------------------------------
  -- write a string to a file; overwriting original file
  
  procedure write_file ( filename : in string; msg : in string) is
    file wr_file       : text open write_mode is filename;
    variable textline  : line;
  begin
    write( textline, msg );
    writeline(wr_file, textline);
  end write_file;

  --------------------------------------------------------------
  -- write an integer to a file; overwriting original file
  
  procedure write_file ( filename : in string; msg : in integer) is
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
  
end file_pkg;  

------------------------------------------------------------------------
-- constants and types for kirsch edge detection
------------------------------------------------------------------------
  
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

use work.string_pkg.all;
use work.file_pkg.all;
use work.kirsch_synth_pkg.all;

package kirsch_unsynth_pkg is
  
  --------------------------------------------------------------
  -- conversions for directions

  function to_string ( dir : direction_ty ) return string;
  
  --------------------------------------------------------------
  -- read/write images from/to files
  
  impure function read_image( filename : string ) return image_ty;

  procedure write_image( filename : in string; image : in image_ty);

  -- type text_file is file of text;
  
  procedure write_edge_dir
              ( file wr_file  : text;
                edge     : in std_logic ;
                dir      : in direction_ty;
                row_idx,
                col_idx  : in integer
              );
  
end kirsch_unsynth_pkg;

package body kirsch_unsynth_pkg is

  --------------------------------------------------------------
  -- convert a direction into a string
  function to_string ( dir : direction_ty ) return string is
  begin
    case dir is
      when dir_ne => return "NE";
      when dir_sw => return "SW";
      when dir_n  => return "N ";
      when dir_s  => return "S ";
      when dir_w  => return "W ";
      when dir_e  => return "E ";
      when dir_nw => return "NW";
      when dir_se => return "SE";
      when others => return "XX";
    end case;
  end to_string;

  --------------------------------------------------------------
  -- append edge, direction, row, col to a file
  
  procedure write_edge_dir
              ( file wr_file  : text;
                edge          : in std_logic;
                dir           : in direction_ty;
                row_idx,
                col_idx       : in integer)
  is
    variable textline  : line;  
  begin
    if edge = '1' then
      write( textline, 1);
    else
      write( textline, 0);
    end if;
    write( textline, ' ');	  
    write( textline, to_integer(unsigned(dir)));
    write( textline, ' ');	  
    write( textline, row_idx);
    write( textline, ' ');	  
    write( textline, col_idx);
    writeline(wr_file, textline);
  end write_edge_dir;
  
  --------------------------------------------------------------
  -- read an image from a file
  
  impure function read_image ( filename : string ) return image_ty is
    file rd_file      : text open read_mode is filename;
    variable textline : line;
    variable rd_ok    : boolean;
    variable pixel    : integer;
    variable row_min,
             row_max,
             col_min,
             col_max,
             row_idx,
             col_idx  : natural;
    variable image    : image_ty;
  begin
    row_min:= image_ty'low(1);
    row_max:= image_ty'high(1);
    col_min:= image_ty'low(2);
    col_max:= image_ty'high(2);
    
    for row_idx in row_min to row_max loop
      if endfile(rd_file) then
        report ("ERROR: premature end of file at ("&
                to_string(row_idx) &","& to_string(col_idx) &")");
        image(row_idx, col_idx) := pixel_ty(to_unsigned(pixel,8));
      else
        readline(rd_file, textline);
        for col_idx in col_min to  col_max loop
          read( textline, pixel, rd_ok);
          if rd_ok then 
            image(row_idx, col_idx) := pixel_ty(to_unsigned(pixel,8));
          else
            report ("ERROR: premature end of file at ("&
                    to_string(row_idx) &","& to_string(col_idx) &")");
            image(row_idx, col_idx) := pixel_ty(to_unsigned(pixel,8));
          end if;
        end loop;
      end if;
    end loop;
    return image;
  end read_image;
  
  --------------------------------------------------------------
  -- write an image to a file
  
  procedure write_image ( filename : in string; image : in image_ty) is
    file wr_file       : text open write_mode is filename; 
    variable textline  : line;  
    variable pixel     : integer;
    variable row_idx,
             col_idx   : integer;
  begin
    for row_idx in image_ty'low(1) to image_ty'high(1) loop
      for col_idx in image_ty'low(2) to image_ty'high(2) loop
        -- put the pixel in textline
        write( textline, to_integer(image(row_idx, col_idx)));
        -- put a space between the pixels
        write( textline, ' ');	  
      end loop;
      writeline(wr_file, textline);   -- write the line into file
    end loop;
  end write_image;

end kirsch_unsynth_pkg;
