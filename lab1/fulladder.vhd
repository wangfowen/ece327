library ieee;
use ieee.std_logic_1164.all;

entity fulladder is
  port ( i_a, i_b, i_cin     : in  std_logic;
         o_sum, o_cout : out std_logic
  );
end fulladder;

architecture main of fulladder  is
begin
  -- sum instantiation
  u_sum : entity work.sum(main)
    port map (
      i_a   => i_a,
      i_b   => i_b,
      i_cin => i_cin,
      o_sum => o_sum
    );
         
  -- carry instantiation

end architecture;
