--
-- Copyright 1991-2011 Mentor Graphics Corporation
--
-- All Rights Reserved.
--
-- THIS WORK CONTAINS TRADE SECRET AND PROPRIETARY INFORMATION WHICH IS THE PROPERTY OF 
-- MENTOR GRAPHICS CORPORATION OR ITS LICENSORS AND IS SUBJECT TO LICENSE TERMS.
--   

library ieee;
use ieee.std_logic_1164.all;

package pkg is

    attribute foreign : string;

    type pointer IS ACCESS std_logic_vector(3 downto 0);

    type rectype is record
      a : bit;
      b : integer;
      c : real;
      d : time;
      e : bit_vector(3 downto 0);
    end record;

    procedure in_params(
      vhdl_integer          : IN integer;
      vhdl_enum             : IN std_logic;
      vhdl_real             : IN real;
      vhdl_array            : IN string;
      vhdl_rec              : IN rectype;
      variable vhdl_ptr     : IN pointer
    );
    attribute foreign of in_params : procedure is "in_params foreignsp.so";

    procedure out_params(
      vhdl_integer      : OUT integer;
      vhdl_enum         : OUT std_logic;
      vhdl_real         : OUT real;
      vhdl_array        : OUT string;
      vhdl_rec          : OUT rectype;
      variable vhdl_ptr : OUT pointer
    );
    attribute foreign of out_params : procedure is "out_params foreignsp.so";

    function incr_integer( ivar : IN integer ) return integer;
    attribute foreign of incr_integer : function is "incrInteger foreignsp.so";

    function incr_real( rvar : IN real ) return real;
    attribute foreign of incr_real : function is "incrReal foreignsp.so";

    function incr_time( tvar : IN time ) return time;
    attribute foreign of incr_time : function is "incrTime foreignsp.so";

end;

package body pkg is

    procedure in_params(
      vhdl_integer      : IN integer;
      vhdl_enum         : IN std_logic;
      vhdl_real         : IN real;
      vhdl_array        : IN string;
      vhdl_rec          : IN rectype;
      variable vhdl_ptr : IN pointer
    ) is
    begin
      assert false report "ERROR: foreign subprogram not called" severity note;
    end;

    procedure out_params(
      vhdl_integer      : OUT integer;
      vhdl_enum         : OUT std_logic;
      vhdl_real         : OUT real;
      vhdl_array        : OUT string;
      vhdl_rec          : OUT rectype;
      variable vhdl_ptr : OUT pointer
    ) is
    begin
      assert false report "ERROR: foreign subprogram not called" severity note;
    end;

    function incr_integer( ivar : IN integer ) return integer is
    begin
      assert false report "ERROR: foreign subprogram not called" severity note;
      return 0;
    end;

    function incr_real( rvar : IN real ) return real is
    begin
      assert false report "ERROR: foreign subprogram not called" severity note;
      return 0.0;
    end;

    function incr_time( tvar : IN time ) return time is
    begin
      assert false report "ERROR: foreign subprogram not called" severity note;
      return 0 ns;
    end;

end;

-- -- --

library ieee;
use ieee.std_logic_1164.all;

entity test is
end test;

use work.pkg.all;

architecture only of test is
begin


  p1 : process
    variable int  : integer := 0;
    variable enum : std_logic := 'U';
    variable r    : real := 0.0;
    variable s    : string(1 to 5) := "abcde";
    variable rec  : rectype := ( '1', 42, 3.7, 5 ns, "1010" );
    variable ivar  : integer := 0;
    variable rvar : real := 0.0;
    variable tvar : time := 1 ns;
    variable ps   : pointer := NULL;
  begin
    wait for 20 ns;
    ps := new std_logic_vector(3 downto 0);
    ps.ALL := ('U', 'Z', 'U', 'Z');
    in_params(int, enum, r, s, rec, ps);
    out_params(int, enum, r, s, rec, ps);
    ivar := incr_integer( ivar );
    rvar := incr_real( rvar );
    tvar := incr_time( tvar );
  end process;

end;
