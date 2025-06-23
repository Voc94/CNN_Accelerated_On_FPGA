library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity tb_uart_debug is
end entity;

architecture sim of tb_uart_debug is
  constant CLK_FREQ    : integer := 100_000_000;
  constant BAUD_RATE   : integer := 115200;
  constant BIT_PERIOD  : time    := 1 sec / BAUD_RATE;
  constant CLK_PERIOD  : time    := 10 ns;
  constant NUM_ADDR    : integer := 4;
  constant ADDR_WIDTH  : integer := 4;
  constant DATA_WIDTH  : integer := 16;
  constant TOTAL_BYTES : integer := NUM_ADDR * 2;

  signal clk           : std_logic := '0';
  signal rst           : std_logic := '1';
  signal uart_rx       : std_logic := '1';
  signal uart_tx       : std_logic;
  signal start_read    : std_logic := '0';
  signal bram_addr     : unsigned(ADDR_WIDTH-1 downto 0);
  signal bram_rd_data  : std_logic_vector(DATA_WIDTH-1 downto 0);

  type ram_t is array (0 to NUM_ADDR-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
  signal fake_bram : ram_t := (
    0 => x"1234",
    1 => x"5678",
    2 => x"ABCD",
    3 => x"DEAD"
  );

  file logf : text open write_mode is "uart_debug_log.txt";
begin

  -- Clock generator
  clk_gen : process
  begin
    loop
      clk <= '0'; wait for CLK_PERIOD / 2;
      clk <= '1'; wait for CLK_PERIOD / 2;
    end loop;
  end process;

  -- Reset generator
  rst_proc : process
  begin
    wait for 50 ns;
    rst <= '0';
    wait;
  end process;

  -- Connect BRAM
  bram_rd_data <= fake_bram(to_integer(bram_addr));

  -- Stimulus
  stim_proc : process
  begin
    wait for 100 ns;
    start_read <= '1';
    wait for CLK_PERIOD;
    start_read <= '0';
    wait; -- Wait forever, simulation ends when UART RX is done
  end process;

  -- UART RX Process (Testbench Receiver)
  uart_rx_proc : process
  variable L          : line;
  variable rx_byte    : std_logic_vector(7 downto 0);
  variable bit_index  : integer;
  variable byte_count : integer := 0;
begin
  while byte_count < TOTAL_BYTES loop
    wait until uart_tx = '1';          -- Wait until idle line (stop bit)
    wait until falling_edge(uart_tx);  -- Wait for start bit
    wait for BIT_PERIOD * 1.5;         -- Align to middle of bit 0

    for bit_index in 0 to 7 loop
      rx_byte(bit_index) := uart_tx;
      wait for BIT_PERIOD;
    end loop;

    wait for BIT_PERIOD; -- Stop bit

    -- Log received byte
    write(L, string'("UART RX [byte "));
    write(L, byte_count);
    write(L, string'("] @ "));
    write(L, now);
    write(L, string'(": 0x"));
    hwrite(L, rx_byte);
    writeline(logf, L);

    byte_count := byte_count + 1;
  end loop;

  file_close(logf);
  report "UART Debug test complete" severity note;
  wait;
end process;


  -- DUT instantiation
  uut: entity work.uart_debug
    generic map (
      ADDR_WIDTH    => ADDR_WIDTH,
      DATA_WIDTH    => DATA_WIDTH
    )
    port map (
      clk           => clk,
      rst           => rst,
      uart_rx       => uart_rx,
      uart_tx       => uart_tx,
      start_read    => start_read,
      num_addresses => NUM_ADDR,
      bram_addr     => bram_addr,
      bram_rd_data  => bram_rd_data
    );

end architecture;
