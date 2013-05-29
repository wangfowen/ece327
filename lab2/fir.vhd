------------------------------------------------------------------------
-- finite-impulse response filters
------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.fir_synth_pkg.all;

entity fir is
  port(
    clk     : in  std_logic;
    i_data  : in  word;
    o_data  : out word
  );
end entity;

architecture avg of fir is

  signal tap0, tap1 , tap2 , tap3 , tap4
             , prod1, prod2, prod3, prod4
                    , sum2 , sum3 , sum4
       : word;

  constant coef1 : word := x"0400";
  constant coef2 : word := x"0400";
  constant coef3 : word := x"0400";
  constant coef4 : word := x"0400";

begin

  -- delay line of flops to hold samples of input data
  tap0 <= i_data;
  delay_line : process(clk)
  begin
    if (rising_edge(clk)) then
      tap1 <= tap0;
      tap2 <= tap1;
      tap3 <= tap2;
      tap4 <= tap3;
    end if;
  end process;

  -- simple averaging circuit
  --
  prod1 <= mult( tap1, coef1);
  prod2 <= mult( tap2, coef2);
  prod3 <= mult( tap3, coef3);
  prod4 <= mult( tap4, coef4);

  sum2  <= prod1 + prod2;
  sum3  <= sum2  + prod3;
  sum4  <= sum3  + prod4;

  o_data <= sum4;

end architecture;

------------------------------------------------------------------------
-- low-pass filter
------------------------------------------------------------------------

architecture low_pass of fir is

  -- Use the signal names tap, prod, and sum, but change the type to
  -- match your needs.

  signal tap, prod, sum : std_logic;

  -- The attribute line below is usually needed to avoid a warning
  -- from PrecisionRTL that signals could be implemented using
  -- memory arrays.

  attribute logic_block of tap, prod, sum : signal is true;

begin

end architecture;

-- question 2
  -- The number of LUTS needed for a 16-bit adder is 16, because the carry of an LE in the FPGA must be used.
  -- By systematically removing adders in the fir(avg) design, we can see this to be true.
  -- There are 16 LUTS used for an adder except for the first sum2 adder, to which there is an optimization down to 15 LUTS.

-- question 3
  -- For multplication of constants, we can see that the multiplier uses no LUTS. This makes sense
  -- because we can simply shift (multiply by a factor of 2) by moving wires.
  -- If we were multiplying the input by itself, then we would use an FPGA DSP, which is seen when this is tested.
  -- This also makes sense, since there are no optimizations on constants that can be done.
