--
-- Copyright 1991-2011 Mentor Graphics Corporation
--
-- All Rights Reserved.
--
-- THIS WORK CONTAINS TRADE SECRET AND PROPRIETARY INFORMATION WHICH IS THE PROPERTY OF 
-- MENTOR GRAPHICS CORPORATION OR ITS LICENSORS AND IS SUBJECT TO LICENSE TERMS.
--   

library IEEE;
use IEEE.std_logic_1164.all;

entity transceiver is
    port ( a: inout std_logic_vector(7 downto 0);
           b: inout std_logic_vector(7 downto 0);
           dir: in std_logic;
           oe:  in std_logic
         );
end transceiver;

architecture behavior of transceiver is
begin
    process(A, B, OE, DIR)
    begin
        case (to_X01(oe)) is
            when '1' =>
                A <= "ZZZZZZZZ";
                B <= "ZZZZZZZZ";
            when '0' =>
                case (to_X01(dir)) is
                    when '0' =>
                        B <= "ZZZZZZZZ";
                        A <= to_X01(B);
                    when '1' =>
                        A <= "ZZZZZZZZ";
                        B <= to_X01(A);
                    when 'X' =>
                        A <= "XXXXXXXX";
                        B <= "XXXXXXXX";
                end case;
            when others =>
                A <= "XXXXXXXX";
                B <= "XXXXXXXX";
        end case;
    end process;
end behavior;
