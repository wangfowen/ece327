--lib_kirsch.vhd
--this file contains uw_uart,uart,ssdc and sevensegment

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
        --!!MDA when others =>
        --!!MDA  TxFSM <= Idle;
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
            Rx_Par <= '0';
          else
            Rx_Par <= '1';
          end if;
          if Rx_r = '0' then
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
        --!!MDA when others => -- in case it would be encoded as safe + binary
        --!!MDA   RxFSM <= Idle;
      end case;
    end if;
  end process;
  
end RTL;
  
  
  
-------------------------------------------------------------------------------
-- uw_uart
-- this code handles the communication between PC and FPGA board
-- using UART IP core for (ece327)project.
-- upon receiving one byte from PC, an acknowledgement byte is sent back to PC
-- last revision: 29 October 2004 
-- Copyright(c) 2004, University of Waterloo, F. Khalvati

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uw_uart is
  port (
    --------------------------------
    -- board-side connections
    --
    clk        : in  std_logic;
    rst        : in  std_logic;
    kirschout  : in  std_logic;
    kirschdir  : in  std_logic_vector(2 downto 0);    
    o_valid    : in  std_logic;
    i_mode     : in  std_logic_vector(1 downto 0);
    datain     : out std_logic_vector(7 downto 0); -- from urts
    o_pixavail : out std_logic;
    --------------------------------
    -- pc-side connections
    --
    rxflex     : in  std_logic; -- rx input    
    txflex     : out std_logic  -- tx output
  );
end uw_uart;

architecture main of uw_uart is
  
  signal baud         : std_logic;
  signal dipsw        : std_logic; -- baud rate selection
  signal sdin         : std_logic_vector (7 downto 0);-- from uarts
  signal rxerr        : std_logic;
  signal rxrdy        : std_logic;                    -- from uarts
  signal rawrx        : std_logic;  
  signal sdout        : std_logic_vector(7 downto 0);  --data to uart and pc
  signal dataoutavail : std_logic;           
  signal rdata        : std_logic_vector (7 downto 0);         
  signal charavail    : boolean;
  signal dataout      : std_logic;

  type   state_type is  (idle,send);
  signal state        : state_type;
  
  signal dsend        : std_logic;--data ready to send
  signal mdata        : std_logic_vector (7 downto 0);
  signal ack          : std_logic;--data ready to send
  signal waitcount    : unsigned(15 downto 0);
  signal ld_sdout     : std_logic;

begin

  baud  <= dipsw;
  dipsw <= '1';
  rawrx <= rxflex when rst='0' else '0';    
     -- txflex <= txflex when rst='0' else '0'; 
          
  i_uarts : entity work.uarts(rtl)
    port map(
      clk    => clk,
      rst    => rst,
      baud   => baud,
      din    => sdout,
      ld     => ld_sdout,
      rx     => rawrx,
      dout   => sdin,
      rxerr  => rxerr,
      rxrdy  => rxrdy,
      tx     => txflex
    );

 
  dataout      <= kirschout;
  dataoutavail <= o_valid; 

  process (clk,rst)
  begin
    if rst='1' then
       rdata <= (others=>'0');
       charavail <= false;
    elsif rising_edge(clk) then
      if rxrdy='1' then  -- memorize the incoming char
         rdata <= sdin;
         charavail <= true;
      end if;
      if charavail then
        charavail <= false;
      end if; 
    end if;   
  end process;   


  process begin
    wait until rising_edge(clk);
    if rst='1' then
      waitcount <= to_unsigned(0,16);
      ack       <= '0';
      dsend     <= '0';
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
          dsend <= '1';
          mdata <= "0000" & kirschdir & dataout;
          --  if  txbusy='0' and rts='1'  then --  busy with sending the prevoius data   
          ack<='0';
          waitcount<=to_unsigned(0,16);
        end if;
      elsif rxerr='1' then
        dsend <= '1';
        mdata <= "11110000"; -- tell pc that there is an error in previous data
      end if;
      if i_mode="01" then
        dsend <= '1';
        mdata <= "00110000";   -- tell pc that reset has occured             
      end if;
    end if;
  end process;

  o_pixavail <= '1' when charavail else '0';
  datain     <= rdata when charavail else (others=>'0');

  process (clk,rst)
  begin
    if rst='1' then
      state    <= idle;
      sdout    <= (others => '0');
      ld_sdout <= '0';
    elsif rising_edge(clk) then
      case state is
        when idle =>
          if dsend='1' then
            state <= send;
            sdout<=mdata;
            ld_sdout <= '1';  
          else
            state<=idle;
          end if;
        when send=>
          state <=idle;
          ld_sdout <= '0';
        --!!MDA: when others =>
        --!!MDA:   state <= idle;
        --!!MDA:   ld_sdout <= '0';
      end case;
    end if;
  end process;
end main;

