------------------------------------------------------------------------
-- lib_lab3.vhd
-- this file contains uw_uart,uart,ssdc and sevensegment
------------------------------------------------------------------------

-- UARTS.vhd
-- -----------------------------------------------------------------------
--   Synthesizable Simple UART - VHDL Model
--   (c) ALSE - cannot be used without the prior written consent of ALSE
-- -----------------------------------------------------------------------
--  Version  : 5.1
--  Date     : Oct 2004
--  Author   : Bert CUZEAU
--  Contact  : info@alse-fr.com
--  Web      : http://www.alse-fr.com
-- ---------------------------------------------------------------
--  FUNCTION :
--    Asynchronous RS232 Transceiver with internal Baud rate generator.
--    This model is synthesizable to any technology. No internal Fifo.
--
--    Can use any Xtal but verify that :
--       Fxtal / max(Baudrate) is accurate enough
--    For very high speeds, it is recommended to use specific
--    Xtal frequencies like 18.432 MHz, etc...
--    Transmit & Receive occur with identical format.
--
--    ----------------
--   | Baud |  Rate   |
--   |------|---------|
--   |   1  |  Baud1  |  115200 by default
--   |   0  |  Baud2  |  19.200 by default
--    ----------------
--
--
--  Generics / Default values :
--  -------------------------
--    Fxtal  = Main Clock frequency in Hertz
--    Parity = False if no parity wanted
--    Even   = True / False, ignored if not parity
--    Baud1  = Baud rate # 1
--    Baud2  = Baud rate # 1
--
--   Typical Area :  (depends on division factor)
--     ~ 100 LCs (Flex 10k)
--     ~ 45 CLB slices (Spartan 2)
--   You can use almost any VHDL synthesis tool
--   like LeonardoSpectrum, Synplify, XST (ISE), QuartusII, etc...
--
--   Design notes :
--
--   1. Baud rate divisor constants are computed automatically
--      with the Fxtal Generic value.
--
--   2. Format options (Use of Parity & Even/Odd format)
--     are static choices (Generic map), but they
--     could easily be made dynamic (format inputs)
--
--   3. Invalid characters do not generate an RxRDY.
--     this can be modified easily in RxOVF State.
--
--   4. The Tx & Rx State Machines are resync'd Mealy type, and
--     they could be encoded as binary (one-hot isn't very useful).
--
--   Modifications :
--     Added internal resync FlipFlop on Rx & RTS.
--     you don't have to resynchronize them externally.
--
--  v4.1 :
--   * fixed a bug in the parity calculation
--   * removed RegDin (smaller by 8 x FlipFlops)
--
--  v 5.1 :
--   * fixed a glitch in the Idle / first bit transition
--     (ClrDiv removed)
--
--   Open Issues :
--     The sampling could be more sophisticated, and we could have more
--     frame checking done.
--     Moreover, framing errors handling could be better.
--     In fact, we assume that there will be no error...
--     which is often the case : this UART has flawlessly exchanged
--     millions of bytes. Moreover, sensitive data should always be
--     checked within a data exchange protocol (CRC, checksum,...).
--
-- ---------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

Entity UARTS is

  -- Notes :
  --   Nb of Stop bits = 1 (always)
  --   format "N81" is generic map(Fxtal,false,false), >> by default <<
  --   format "8E1" is generic map(Fxtal,true,true)

  Port (  CLK     : in  std_logic;  -- System Clock at Fqxtal
          RST     : in  std_logic;  -- Asynchronous Reset active high

          Din     : in  std_logic_vector (7 downto 0);
          LD      : in  std_logic;  -- Load, must be pulsed high
          Rx      : in  std_logic;

          Baud    : in  std_logic;  -- Baud Rate Select Baud1 (1) / Baud2 (0)

          Dout    : out std_logic_vector(7 downto 0);
          Tx      : out std_logic;
          TxBusy  : out std_logic;  -- '1' when Busy sending
          RxErr   : out std_logic;
          RxRDY   : out std_logic   -- '1' when Data available
       );
end UARTS;


Architecture RTL of UARTS is
 constant Fxtal   : integer  := 50000000;-- in Hertz
 constant Parity  : boolean  := false;
 constant Even    : boolean  := false;
 constant Baud1   : positive := 115200;
 constant Baud2   : positive :=  19200;


  function myMin ( i, j : integer) return integer is
  begin
    if i <= j then return i; else return j; end if;
  end function;
  
  constant Debug : integer := 0;
  constant MaxFactor : positive := Fxtal / MyMin (Baud1,Baud2);
  
  constant Divisor1 : positive := (Fxtal / Baud1) / 2;
  constant Divisor2 : positive := (Fxtal / Baud2) / 2;
  
  Type TxFSM_State is (Idle, Load_Tx, Shift_TX, Parity_Tx, Stop_Tx  );
  signal TxFSM : TxFSM_State;
  
  Type RxFSM_State is (Idle, Start_Rx, Shift_RX, Edge_Rx,
                       Parity_Rx, Parity_2, Stop_Rx, RxOVF );
  signal RxFSM : RxFSM_State;
  
  signal Tx_Reg : std_logic_vector (8 downto 0);
  signal Rx_Reg : std_logic_vector (7 downto 0);
  
  signal RxDivisor: integer range 0 to MaxFactor/2; -- Rx division factor
  signal TxDivisor: integer range 0 to MaxFactor;   -- Tx division factor
  
  signal RxDiv : integer range 0 to MaxFactor/2;
  signal TxDiv : integer range 0 to MaxFactor;
  
  signal TopTx : std_logic;
  signal TopRx : std_logic;
  
  signal TxBitCnt : integer range 0 to 15;
  
  signal RxBitCnt : integer range 0 to 15;
  signal RxRDYi   : std_logic;
  signal Rx_Par   : std_logic; -- Receive parity built
  signal Tx_Par   : std_logic; -- Transmit parity built
  
  signal Rx_r    : std_logic;  -- resync FlipFlop for Rx input

begin

  RxRDY <= RxRDYi;

  --------------------------------------------------------------
  -- Rx input resynchronization
  
  process (RST, CLK)
  begin
    if RST='1' then
      Rx_r  <= '1';  -- avoid false start bit at powerup
    elsif rising_edge(CLK) then
      Rx_r <= Rx;
    end if;
  end process;
  

  --------------------------------------------------------------
  --  Baud Rate conversion
  --
  -- Note that constants are (actual_divisor - 1)
  -- You can easily add more BaudRates by extending the "case" instruction...
  
  process (RST, CLK)
  begin
    if RST='1' then
      RxDivisor <= 0;
      TxDivisor <= 0;
    elsif rising_edge(CLK) then
      case Baud is
        when '0' =>    RxDivisor <= Divisor2 - 1;
                       TxDivisor <= (2 * Divisor2) - 1;
        when '1' =>    RxDivisor <= Divisor1 - 1;
                       TxDivisor <= (2  * Divisor1) - 1;
        when others => RxDivisor <= 1;   -- n.u.
                       TxDivisor <= 1;
      end case;
    end if;
  end process;
  
  --------------------------------------------------------------
  --  Rx Clock Generation
  --
  -- Periodicity : bit time / 2
  
  process (RST, CLK)
  begin
    if RST='1' then
      RxDiv <= 0;
      TopRx <= '0';
    elsif rising_edge(CLK) then
      TopRx <= '0';
      if RxFSM = Idle then
        RxDiv <= 0;
      elsif RxDiv = RxDivisor then
        RxDiv <= 0;
        TopRx <= '1';
      else
        RxDiv <=  RxDiv + 1;
      end if;
    end if;
  end process;
  
  
  --------------------------------------------------------------
  --  Tx Clock Generation
  --
  -- Periodicity : bit time
  
  process (RST, CLK)
  begin
    if RST='1' then
      TxDiv <= 0;
      TopTx <= '0';
    elsif rising_edge(CLK) then
      TopTx <= '0';
      if TxDiv = TxDivisor then
        TxDiv <= 0;
        TopTx <= '1';
      else
        TxDiv <=  TxDiv + 1;
      end if;
    end if;
  end process;
  
  
  --------------------------------------------------------------
  --  TRANSMIT State Machine
  --
  
  TX <= Tx_Reg(0); -- LSB first
  
  Tx_FSM: process (RST, CLK)
  begin
    if RST='1' then
      Tx_Reg   <= (others => '1'); -- Line=Vcc when no Xmit
      TxFSM    <= Idle;
      TxBitCnt <= 0;
      TxBusy   <= '0';
      Tx_Par   <= '0';
    elsif rising_edge(CLK) then
      TxBusy <= '1';  -- Except when explicitly '0'
      case TxFSM is
        when Idle =>
          if LD='1' then
            Tx_Reg <= Din & '1';      -- Latch input data immediately.
            TxBusy <= '1';
            TxFSM <= Load_Tx;
          else
            TxBusy <= '0';
          end if;
        when Load_Tx =>
          if TopTx='1' then
            TxFSM  <= Shift_Tx;
            Tx_Reg(0) <= '0'; -- Start bit
            TxBitCnt <= 9;
            if Parity then      -- Start + Data + Parity
              if Even  then
                Tx_Par <= '0';
              else
                Tx_Par <= '1';
              end if;
            end if;
          end if;
        when Shift_Tx =>
          if TopTx='1' then     -- Shift Right with a '1'
            TxBitCnt <= TxBitCnt - 1;
            Tx_Par <= Tx_Par xor Tx_Reg(1);  -- <<< error in v4.0 fixed in v4.1
            Tx_Reg <= '1' & Tx_Reg (Tx_Reg'high downto 1);
            if TxBitCnt=1 then
              if not parity then
                TxFSM <= Stop_Tx;
              else
                Tx_Reg(0) <= Tx_Par;
                TxFSM <= Parity_Tx;
              end if;
            end if;
          end if;
        when Parity_Tx =>       -- Parity bit
          if TopTx='1' then
            Tx_Reg(0) <= '1'; -- Stop bit value
            TxFSM <= Stop_Tx;
          end if;
        when Stop_Tx =>         -- Stop bit
          if TopTx='1' then
            TxFSM <= Idle;
          end if;
        when others =>
          TxFSM <= Idle;
      end case;
    end if;
  end process;
  
  --------------------------------------------------------------
  --  RECEIVE State Machine
  
  Rx_FSM: process (RST, CLK)
  
  begin
    if RST='1' then
      Rx_Reg   <= (others => '0');
      Dout     <= (others => '0');
      RxBitCnt <= 0;
      RxFSM    <= Idle;
      RxRdyi   <= '0';
      RxErr    <= '0';
      Rx_Par   <= '0';
    elsif rising_edge(CLK) then
      if RxRdyi='1' then  -- Clear error bit when a word has been received...
        RxErr  <= '0';
        RxRdyi <= '0';
      end if;
      case RxFSM is
        when Idle =>      -- Wait until start bit occurs
          RxBitCnt <= 0;
          if Even then
            Rx_Par<='0';
          else Rx_Par<='1';
          end if;
          if Rx_r='0' then
            RxFSM  <= Start_Rx;
          end if;
        when Start_Rx =>  -- Wait on first data bit
          if TopRx = '1' then
            if Rx_r='1' then -- framing error
              RxFSM <= RxOVF;
              -- pragma translate_off
              assert (debug < 1) report "Start bit error."
                severity warning;
              -- pragma translate_on
            else
              RxFSM <= Edge_Rx;
            end if;
          end if;
        when Edge_Rx =>   -- should be near Rx edge
          if TopRx = '1' then
            RxFSM <= Shift_Rx;
            if RxBitCnt = 8 then
              if Parity then
                RxFSM <= Parity_Rx;
              else
                RxFSM <= Stop_Rx;
              end if;
            else
              RxFSM <= Shift_Rx;
            end if;
          end if;
        when Shift_Rx =>  -- Sample data !
          if TopRx = '1' then
            RxBitCnt <= RxBitCnt + 1;
            Rx_Reg   <= Rx_r & Rx_Reg (Rx_Reg'high downto 1); -- shift right
            Rx_Par   <= Rx_Par xor Rx_r;
            RxFSM    <= Edge_Rx;
          end if;
        when Parity_Rx => -- Sample the parity
          if TopRx = '1' then
            if (Rx_Par = Rx_r) then
              RxFSM <= Parity_2;
            else
              RxFSM <= RxOVF;
            end if;
          end if;
        when Parity_2 =>  -- second half Bit period wait
          if TopRx = '1' then
            RxFSM <= Stop_Rx;
          end if;
        when Stop_Rx =>   -- here during Stop bit
          if TopRx = '1' then
            if Rx_r='1' then
              Dout <= Rx_reg;
              RxRdyi <='1';
              RxFSM <= Idle;
              -- pragma translate_off
              assert (debug < 1)
                report "Character received in decimal is : "
                  & integer'image(to_integer(unsigned(Rx_Reg)))
                  & " - '" & character'val(to_integer(unsigned(Rx_Reg))) & "'"
                  severity note;
              -- pragma translate_on
            else
              RxFSM <= RxOVF;
            end if;
          end if;
        -- ERROR HANDLING COULD BE IMPROVED :
        -- Here, we could try to re-synchronize !
        when RxOVF =>     -- Overflow / Error : should we RxRDY ?
          RxRdyi <= '0'; -- or '1' : to be defined by the project
          RxErr  <= '1';
          if Rx = '1' then  -- return to idle as soon as Rx goes inactive
          -- pragma translate_off
          report "Error in character received. " severity warning;
          -- pragma translate_on
            RxFSM <= Idle;
          end if;
        when others => -- in case it would be encoded as safe + binary...
          RxFSM <= Idle;
      end case;
    end if;
  end process;
  
end RTL;
  
  
  
------------------------------------------------------------------------
-- uw_uart
-- this code handles the communication between PC and FPGA board using
-- UART IP core for (ece327)project.
-- upon receiving one byte from PC, an acknowledgement byte is sent back to PC
-- last revision: 29 October 2004 
-- Copyright(c) 2004, University of Waterloo, F. Khalvati

LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

Entity uw_uart is
  Port (
    CLK : In  std_logic;
    RST : In  std_logic;
    RXFLEX : In    std_logic; -- RX input    
    datain : Out std_logic_vector(7 downto 0); -- from URTS
    TXFLEX : Out   std_logic; -- TX output
    o_pixavail:out std_logic
  );
end uw_uart;


Architecture main of uw_uart is
  signal Baud : STD_LOGIC;
  signal DIPSW :std_logic; -- Baud rate selection
  signal SDin : std_logic_vector (7 downto 0);-- from UARTS
  signal RxErr : STD_LOGIC;
  signal RxRDY : std_logic;                    -- from UARTS
  signal TxBusy : std_logic;
  signal RTS : std_logic; -- resync FLipFlop on RTS
  signal RawRx : std_logic;
  signal lab3out : std_logic_vector(7 downto 0);
  signal sdout : std_logic_vector(7 downto 0);  --data to UART and PC
  signal dataoutavail: std_logic;           
  signal RData : std_logic_vector (7 downto 0);         
  signal CharAvail : boolean;
  signal Dataout :std_logic_vector(7 downto 0);         
  type   State_Type is  (Idle,send);
  signal State: State_Type;
  signal dsend: std_logic;--data ready to send
  signal mdata:std_logic_vector (7 downto 0);
  signal ack: std_logic;--data ready to send
  signal waitcount:unsigned(15 downto 0);
  signal LD_SDOUT : std_logic;
begin
  Baud <= DIPSW;
  DIPSW<='1';
  RawRx <= RXFLEX when rst='0' else '0';    
  -- TXFLEX <= TXFLEX when rst='0' else '0'; 
  RTS <= '1';  -- permanently enabled
          
  u_UARTS : entity work.UARTS(rtl) 
    Port map (
      CLK    => CLK,
      RST    => rst,
      Baud   => Baud,
      Din    => SDout,
      LD     => LD_SDout,
      Rx     => RawRx,
      Dout   => SDin,
      RxErr  => RxErr,
      RxRDY  => RxRDY,
      Tx     => TXFLEX,
      TxBusy => TxBusy
    );

 Dataout      <= lab3out;
 dataoutavail <= '0'; 

  process (CLK,RST)
  begin
    if RST='1' then
       RData <= (others=>'0');
       RTS <= '0';
       CharAvail <= false;
    elsif rising_edge(CLK) then
      if RxRDY='1' then  -- memorize the incoming char
         RData <= SDin;
         CharAvail <= true;
      end if;
      if CharAvail then
         CharAvail <= false;
      end if; 
    end if;   
  end process;   

  process
  begin
    wait until rising_edge(clk);
    if rst='1' then
      waitcount<=to_unsigned(0,16);
      ack<='0';
      dsend<='0';
    else   
      dsend<='0';
      if charavail or ack='1' then
        ack<='1';
        if dataoutavail='0' then
          waitcount<=waitcount+to_unsigned(1,16);
          if waitcount=to_unsigned(100,16) then    
            dsend<='1';
            mdata<="11111111";
            ack<='0';
            waitcount<=to_unsigned(0,16);
          end if;  
        elsif dataoutavail='1' then
          mdata <= dataout;
          dsend <= dataoutavail;
          --  if  TxBusy='0' and RTS='1'  then --  busy with sending prev data
          ack<='0';
          waitcount<=to_unsigned(0,16);
        end if;
      elsif RxErr='1' then
        dsend<='1';
        mdata<="11110000";  -- tell PC  error in previous data             
      end if;
    end if;
  end process;

  o_pixavail<='1' when charavail else '0';
  Datain<=Rdata when charavail else (others=>'0');

  process (CLK,RST)
  begin
    if RST='1' then
      state<=idle;
      LD_SDout <= '0';
    elsif rising_edge(CLK) then
      case State is
        when Idle =>
          if dsend='1' then
            State <= send;
            sdout<=mdata;
            LD_SDout <= '1';  
          else
            STATE<=idle;
          end if;
        when Send=>
          State <=idle;
          LD_SDout <= '0';
        when others =>
          State <= Idle;
          LD_SDout <= '0';
      end case;
    end if;
  end process;
  
end main;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package lab3_pkg is
  function to_sevenseg( digit : unsigned(3 downto 0); period : std_logic)
    return std_logic_vector;
end package;

package body lab3_pkg is
  function to_sevenseg( digit : unsigned(3 downto 0); period : std_logic)
    return std_logic_vector
  is
    variable tmp    : std_logic_vector( 6 downto 0 );
    variable result : std_logic_vector( 7 downto 0 );
  begin
    result(7) := not( period );
    case digit is
      when to_unsigned(  0, 4 ) => tmp := "0000001";
      when to_unsigned(  1, 4 ) => tmp := "1001111";
      when to_unsigned(  2, 4 ) => tmp := "0010010";
      when to_unsigned(  3, 4 ) => tmp := "0000110";
      when to_unsigned(  4, 4 ) => tmp := "1001100";
      when to_unsigned(  5, 4 ) => tmp := "0100100";
      when to_unsigned(  6, 4 ) => tmp := "0100000";
      when to_unsigned(  7, 4 ) => tmp := "0001111";
      when to_unsigned(  8, 4 ) => tmp := "0000000";
      when to_unsigned(  9, 4 ) => tmp := "0001100";
      when to_unsigned( 10, 4 ) => tmp := "0001000";
      when to_unsigned( 11, 4 ) => tmp := "1100000";
      when to_unsigned( 12, 4 ) => tmp := "0110001";
      when to_unsigned( 13, 4 ) => tmp := "1000010";
      when to_unsigned( 14, 4 ) => tmp := "0110000";
      when to_unsigned( 15, 4 ) => tmp := "0111000";
      when others               => tmp := (others => 'X');
    end case;
    result( 6 downto 0 ) := tmp;
    return result;
  end function;
end package body;



