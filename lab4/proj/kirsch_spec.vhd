------------------------------------------------------------------------
-- reference model specification for kirsch edge detector
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.kirsch_synth_pkg.all;
use work.kirsch_unsynth_pkg.all;

entity kirsch is
  port(
    ------------------------------------------
    -- main inputs and outputs
    i_clock    : in  std_logic;                      
    i_reset    : in  std_logic;                      
    i_valid    : in  std_logic;                 
    i_pixel    : in  std_logic_vector(7 downto 0); 
    o_valid    : out std_logic;                 
    o_edge     : out std_logic;	                     
    o_dir      : out std_logic_vector(2 downto 0);                      
    o_mode     : out std_logic_vector(1 downto 0);
    o_row      : out std_logic_vector(7 downto 0);
    ------------------------------------------
    -- debugging inputs and outputs
    debug_key      : in  std_logic_vector( 3 downto 1) ; 
    debug_switch   : in  std_logic_vector(17 downto 0) ; 
    debug_led_red  : out std_logic_vector(17 downto 0) ; 
    debug_led_grn  : out std_logic_vector(5  downto 0) ; 
    debug_num_0    : out std_logic_vector(3 downto 0) ; 
    debug_num_1    : out std_logic_vector(3 downto 0) ; 
    debug_num_2    : out std_logic_vector(3 downto 0) ; 
    debug_num_3    : out std_logic_vector(3 downto 0) ; 
    debug_num_4    : out std_logic_vector(3 downto 0) ;
    debug_num_5    : out std_logic_vector(3 downto 0) 
    ------------------------------------------
  );  
end kirsch;


architecture main of kirsch is

  --------------------------------------------------------------
  -- 3x3 table of pixels for edge detection

  type table_ty is array (0 to 2, 0 to 2) of integer range -1024 to 1024;

  --------------------------------------------------------------
  -- record type to hold edge and direction

  type edge_dir_t is
    record
      edge : std_logic;
      dir  : direction_ty;
    end record;

  --------------------------------------------------------------
  -- edge detection function
  --
  -- inside a function we cannot use signals; must use variables

  function edge_detect ( T : table_ty ) return edge_dir_t is
    
    -- eight derivatives 
    variable 
      deriv_n,  deriv_s,  deriv_e,  deriv_w, 
      deriv_ne, deriv_nw, deriv_se, deriv_sw  : integer range -3900 to 3900 ;

    -- value of maximum derivative, compare with threshold
    variable max_deriv : integer;

    -- direction of edge
    variable edge_dir : direction_ty;

  begin

    ----------------------------------------------------
    -- calculate derivative for each of the eight directions

    deriv_e  :=   5*(T(0,2) + T(1,2) + T(2,2))
                - 3*(T(0,1) + T(0,0) + T(1,0) + T(2,0) + T(2,1));
    deriv_ne :=	  5*(T(0,1) + T(0,2) + T(1,2))
                - 3*(T(0,0) + T(1,0) + T(2,0) + T(2,1) + T(2,2));
    deriv_n  :=	  5*(T(0,0) + T(0,1) + T(0,2))
                - 3*(T(1,0) + T(2,0) + T(2,1) + T(2,2) + T(1,2));
    deriv_nw :=	  5*(T(1,0) + T(0,0) + T(0,1))
                - 3*(T(2,0) + T(2,1) + T(2,2) + T(1,2) + T(0,2));
    deriv_w  :=	  5*(T(2,0) + T(1,0) + T(0,0))
                - 3*(T(2,1) + T(2,2) + T(1,2) + T(0,2) + T(0,1));
    deriv_sw :=	  5*(T(2,1) + T(2,0) + T(1,0))
                - 3*(T(2,2) + T(1,2) + T(0,2) + T(0,1) + T(0,0));
    deriv_s  :=	  5*(T(2,2) + T(2,1) + T(2,0))
                - 3*(T(1,2) + T(0,2) + T(0,1) + T(0,0) + T(1,0));
    deriv_se :=	  5*(T(1,2) + T(2,2) + T(2,1))
                - 3*(T(0,2) + T(0,1) + T(0,0) + T(1,0) + T(2,0));

    ----------------------------------------------------
    -- find the maximum derivative

    max_deriv := 0;

    if deriv_sw >= max_deriv then
      max_deriv := deriv_sw;
      edge_dir	:= dir_sw;
    end if;
    ------------------------------------------
    if deriv_s >= max_deriv then
      max_deriv := deriv_s;
      edge_dir	:= dir_s;
    end if;
    ------------------------------------------
    if deriv_se >= max_deriv then
      max_deriv := deriv_se;
      edge_dir	:= dir_se;
    end if;
    ------------------------------------------
    if deriv_e >= max_deriv then
      max_deriv := deriv_e;
      edge_dir	:= dir_e;
    end if;
    ------------------------------------------
    if deriv_ne >= max_deriv then
      max_deriv := deriv_ne;
      edge_dir	:= dir_ne;
    end if;
    ------------------------------------------
    if deriv_n >= max_deriv then
      max_deriv := deriv_n;
      edge_dir	:= dir_n;
    end if;
    ------------------------------------------
    if deriv_nw >= max_deriv then
      max_deriv := deriv_nw;
      edge_dir	:= dir_nw;
    end if;
    ------------------------------------------
    if deriv_w >= max_deriv then
      max_deriv := deriv_w;
      edge_dir	:= dir_w;
    end if;
    ------------------------------------------

    ----------------------------------------------------
    -- calculate if there's an edge
    
    if max_deriv > threshold then
      return( (edge => '1', dir => edge_dir ) );
    else
      return( (edge => '0', dir => (others => '0') ) );
    end if;

  end edge_detect;

  --------------------------------------------------------------
  signal row_sig, col_sig : natural;
    
  signal image : image_ty;
  signal table : table_ty;

  signal image_valid : std_logic;
  signal mode        : std_logic_vector(1 downto 0);
  
begin

  process
    begin
      row_loop : for row_idx in 0 to image_height-1 loop
        col_loop : for col_idx in 0 to image_width-1 loop
          wait until rising_edge(i_clock);
          image_valid <= '0';
          exit row_loop when i_reset = '1';
          while i_valid = '0' loop
            wait until rising_edge(i_clock);
          end loop;
          image_valid               <= '1';
          row_sig                   <= row_idx;
          col_sig                   <= col_idx;
          image( row_idx, col_idx ) <= unsigned(i_pixel);
        end loop;
      end loop;
  end process;

  process (image_valid, row_sig, col_sig, image)
  begin
    if image_valid = '1' and row_sig >= 2 and col_sig >= 2 then
      for row_idx in 0 to 2 loop
        for col_idx in 0 to 2 loop
          table(row_idx, col_idx)
            <= to_integer( unsigned(
                 image(row_sig-2+row_idx, col_sig-2+col_idx)
               ));
        end loop;
      end loop;
    end if;
  end process;

  process (image_valid, row_sig, col_sig, table)
  begin
    if image_valid = '1' and row_sig >= 2 and col_sig >= 2 then
      o_valid <= '1';
      (edge => o_edge, dir => o_dir) <= edge_detect( table );
    else
      o_valid <= '0';
      o_edge  <= '-';
      o_dir   <= (others => '-');
    end if;
  end process;

  process
  begin
    wait until rising_edge( i_clock );
    if i_reset = '1' then
      mode <= reset;
    elsif mode = reset and i_reset = '0' then
      mode <= idle;
    elsif mode = idle and i_valid = '1' then
      mode  <= busy;
    elsif mode = busy and
          row_sig = image_height-1 and 
          col_sig = image_width-1
    then
      mode  <= idle;
    end if;
  end process;

  o_mode <= mode;
  o_row  <= std_logic_vector(to_unsigned(row_sig, 8));
  
end main;
