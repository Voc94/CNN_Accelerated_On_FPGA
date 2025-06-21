library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_cmd is
  generic (
    CLK_FREQ  : integer := 100_000_000;
    BAUD_RATE : integer := 115200
  );
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    uart_rx  : in  std_logic;
    uart_tx  : out std_logic;
    led      : out std_logic_vector(3 downto 0)  -- status/debug LEDs
  );
end entity;

architecture RTL of uart_cmd is
  signal rx_data    : std_logic_vector(7 downto 0);
  signal rx_valid   : std_logic;
  signal tx_start   : std_logic := '0';
  signal tx_data    : std_logic_vector(7 downto 0) := (others => '0');
  signal tx_busy    : std_logic;

  -- Simple FSM for command processing
  type state_type is (
  WAIT_CMD,
  RECV_IMAGE,
  PREP_READ,    -- <- NEW
  SEND_IMAGE,
  WAIT_TX
);
signal state        : state_type := WAIT_CMD;
  signal image_index : unsigned(11 downto 0) := (others => '0'); -- 0 to 4095
  signal bram_we     : std_logic := '0';
  signal bram_wr_data : std_logic_vector(7 downto 0) := (others => '0');
  signal bram_rd_data : std_logic_vector(7 downto 0);
    
begin

  uart_inst: entity work.uart
    generic map (
      CLK_FREQ  => CLK_FREQ,
      BAUD_RATE => BAUD_RATE
    )
    port map (
      clk        => clk,
      rst        => rst,
      rx         => uart_rx,
      tx         => uart_tx,
      data_out   => rx_data,
      data_valid => rx_valid,
      tx_start   => tx_start,
      data_in    => tx_data,
      tx_busy    => tx_busy
    );

    img_mem: entity work.image_bram
      port map (
        clk      => clk,
        we       => bram_we,
        wr_addr  => image_index,
        wr_data  => bram_wr_data,
        rd_addr  => image_index,
        rd_data  => bram_rd_data
      );
   process(clk, rst)
begin
  if rst = '1' then
    state        <= WAIT_CMD;
    image_index  <= (others => '0');
    tx_start     <= '0';
    bram_we      <= '0';
    led          <= (others => '0');
  elsif rising_edge(clk) then
    tx_start <= '0';
    bram_we  <= '0';

    case state is
      when WAIT_CMD =>
        if rx_valid = '1' then
          if rx_data = x"10" then
            image_index <= (others => '0');
            state <= RECV_IMAGE;
            led(0) <= '1';
          elsif rx_data = x"20" then
            image_index <= (others => '0');
            state <= PREP_READ;  -- NEW: allow BRAM address setup
            led(1) <= '1';
          end if;
        end if;

      when RECV_IMAGE =>
        if rx_valid = '1' then
          bram_wr_data <= rx_data;
          bram_we <= '1';
          if image_index = to_unsigned(4095, 12) then
            state <= WAIT_CMD;
            led <= (others => '0');
          else
            image_index <= image_index + 1;
          end if;
        end if;

      when PREP_READ =>  -- NEW STATE: wait 1 cycle for read data
        state <= SEND_IMAGE;

      when SEND_IMAGE =>
        if tx_busy = '0' then
          tx_data  <= bram_rd_data;
          tx_start <= '1';
          if image_index = to_unsigned(4095, 12) then
            state <= WAIT_TX;
          else
            image_index <= image_index + 1;
            state <= PREP_READ;  -- go back to load next read data
          end if;
        end if;

      when WAIT_TX =>
        if tx_busy = '0' then
          state <= WAIT_CMD;
          led <= (others => '0');
        end if;

      when others =>
        state <= WAIT_CMD;
    end case;
  end if;
end process;


end architecture;
