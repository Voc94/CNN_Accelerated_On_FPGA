library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;

entity tb_uart is
end tb_uart;

architecture sim of tb_uart is
    constant CLK_FREQ  : integer := 100_000_000;
    constant BAUD_RATE : integer := 9600;
    constant BAUD_TICK : time := 1 sec / BAUD_RATE;

    signal clk        : std_logic := '0';
    signal rst        : std_logic := '1';
    signal uart_rx    : std_logic := '1';
    signal uart_tx    : std_logic;
    signal data_out   : std_logic_vector(7 downto 0);
    signal data_valid : std_logic;
    signal tx_start   : std_logic := '0';
    signal data_in    : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_busy    : std_logic;

    file logfile : text open write_mode is "uart_out.txt";

begin
    ----------------------------------------------------------------
    -- DUT instantiation (assumes 'uart' entity is compiled)
    ----------------------------------------------------------------
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
            data_out   => data_out,
            data_valid => data_valid,
            tx_start   => tx_start,
            data_in    => data_in,
            tx_busy    => tx_busy
        );

    ----------------------------------------------------------------
    -- Clock generation (100 MHz)
    ----------------------------------------------------------------
    clk_proc: process
    begin
        while true loop
            clk <= '0'; wait for 5 ns;
            clk <= '1'; wait for 5 ns;
        end loop;
    end process;

    ----------------------------------------------------------------
    -- Release reset after 100 ns
    ----------------------------------------------------------------
    rst_proc: process
    begin
        wait for 100 ns;
        rst <= '0';
        wait;
    end process;

    ----------------------------------------------------------------
    -- Stimulus: send a few bytes via RX and echo them back via TX
    ----------------------------------------------------------------
    stimulus_proc: process
        procedure send_byte(signal rx_line: out std_logic; data: std_logic_vector(7 downto 0)) is
        begin
            rx_line <= '0'; wait for BAUD_TICK;  -- Start bit
            for i in 0 to 7 loop
                rx_line <= data(i);
                wait for BAUD_TICK;
            end loop;
            rx_line <= '1'; wait for BAUD_TICK;  -- Stop bit
            rx_line <= '1';
        end procedure;

        variable log_line: line;
    begin
        wait for 200 ns;
        -- Log: initial state
        write(log_line, string'("Time="));
        write(log_line, now, right, 14);
        write(log_line, string'(" RX_IDLE TX=" & std_logic'image(uart_tx)));
        writeline(logfile, log_line);

        -- Send 0x55
        send_byte(uart_rx, "01010101");
        wait until data_valid = '1';
        write(log_line, string'("Time="));
        write(log_line, now, right, 14);
        write(log_line, string'(" RX_data="));
        write(log_line, data_out);
        write(log_line, string'(" (0x55 received)"));
        writeline(logfile, log_line);

        -- Echo back via TX
        data_in <= data_out; tx_start <= '1';
        wait for 10 ns; tx_start <= '0';
        wait for BAUD_TICK * 12;

        -- Send 0xAA
        send_byte(uart_rx, "10101010");
        wait until data_valid = '1';
        write(log_line, string'("Time="));
        write(log_line, now, right, 14);
        write(log_line, string'(" RX_data="));
        write(log_line, data_out);
        write(log_line, string'(" (0xAA received)"));
        writeline(logfile, log_line);

        -- Echo back via TX
        data_in <= data_out; tx_start <= '1';
        wait for 10 ns; tx_start <= '0';
        wait for BAUD_TICK * 12;

        wait for 500 ns;
        wait;
    end process;

    ----------------------------------------------------------------
    -- Monitor TX and RX, log any changes
    ----------------------------------------------------------------
    monitor_proc: process(uart_tx, uart_rx)
        variable log_line: line;
    begin
        write(log_line, string'("Time="));
        write(log_line, now, right, 14);
        write(log_line, string'(" RX=" & std_logic'image(uart_rx)));
        write(log_line, string'(" TX=" & std_logic'image(uart_tx)));
        write(log_line, string'(" TX_busy=" & std_logic'image(tx_busy)));
        writeline(logfile, log_line);
    end process;

end sim;
