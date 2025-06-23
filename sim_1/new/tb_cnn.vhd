library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity tb_cnn is
end tb_cnn;

architecture sim of tb_cnn is

  constant CLK_PERIOD : time := 10 ns;

  signal clk     : std_logic := '0';
  signal rst     : std_logic := '1';
  signal uart_rx : std_logic := '1';
  signal uart_tx : std_logic;
  signal led     : std_logic_vector(3 downto 0);
  signal start   : std_logic := '0';

  signal state_out        : std_logic_vector(3 downto 0);
  signal norm_debug_addr  : unsigned(14 downto 0);
  signal norm_debug_data  : std_logic_vector(15 downto 0);
  signal norm_debug_we    : std_logic;
  signal norm_debug_done  : std_logic;
  signal pp_debug_addr    : unsigned(14 downto 0);
  signal pp_debug_data    : std_logic_vector(15 downto 0);
  signal pp_debug_we      : std_logic;

  signal debug_start_out     : std_logic;
  signal debug_uart_addr_out : unsigned(14 downto 0);

  component cnn
    port (
      clk               : in  std_logic;
      rst               : in  std_logic;
      uart_rx           : in  std_logic;
      uart_tx           : out std_logic;
      led               : out std_logic_vector(3 downto 0);
      start             : in  std_logic;
      state_out         : out std_logic_vector(3 downto 0);
      norm_debug_addr   : out unsigned(14 downto 0);
      norm_debug_data   : out std_logic_vector(15 downto 0);
      norm_debug_we     : out std_logic;
      norm_debug_done   : out std_logic;
      pp_debug_addr     : out unsigned(14 downto 0);
      pp_debug_data     : out std_logic_vector(15 downto 0);
      pp_debug_we       : out std_logic;
      debug_start_out   : out std_logic;
      debug_uart_addr_out : out unsigned(14 downto 0)
    );
  end component;

  function to_hex_str(v : std_logic_vector) return string is
    variable result : string(1 to v'length / 4);
    variable nibble : std_logic_vector(3 downto 0);
  begin
    for i in 0 to (v'length / 4 - 1) loop
      nibble := v(v'length - 1 - i*4 downto v'length - 4 - i*4);
      case nibble is
        when "0000" => result(i+1) := '0';
        when "0001" => result(i+1) := '1';
        when "0010" => result(i+1) := '2';
        when "0011" => result(i+1) := '3';
        when "0100" => result(i+1) := '4';
        when "0101" => result(i+1) := '5';
        when "0110" => result(i+1) := '6';
        when "0111" => result(i+1) := '7';
        when "1000" => result(i+1) := '8';
        when "1001" => result(i+1) := '9';
        when "1010" => result(i+1) := 'A';
        when "1011" => result(i+1) := 'B';
        when "1100" => result(i+1) := 'C';
        when "1101" => result(i+1) := 'D';
        when "1110" => result(i+1) := 'E';
        when "1111" => result(i+1) := 'F';
        when others => result(i+1) := '?';
      end case;
    end loop;
    return result;
  end;

begin

  -- Clock process
  clk_process : process
  begin
    while true loop
      clk <= '0';
      wait for CLK_PERIOD / 2;
      clk <= '1';
      wait for CLK_PERIOD / 2;
    end loop;
  end process;

  -- Unit Under Test
  uut: cnn
    port map (
      clk               => clk,
      rst               => rst,
      uart_rx           => uart_rx,
      uart_tx           => uart_tx,
      led               => led,
      start             => start,
      state_out         => state_out,
      norm_debug_addr   => norm_debug_addr,
      norm_debug_data   => norm_debug_data,
      norm_debug_we     => norm_debug_we,
      norm_debug_done   => norm_debug_done,
      pp_debug_addr     => pp_debug_addr,
      pp_debug_data     => pp_debug_data,
      pp_debug_we       => pp_debug_we,
      debug_start_out   => debug_start_out,
      debug_uart_addr_out => debug_uart_addr_out
    );

  -- Stimulus + Logging
  stim_proc : process
    file log_file : text open write_mode is "cnn_log.txt";
    variable line_buf : line;
  begin
    wait for 50 ns;
    rst <= '0';

    wait for 100 ns;
    start <= '1';
    wait for 250 us;
    start <= '0';

    report "Logging during NORMALIZE...";

    while state_out = "0001" loop
      wait for 100 ns;

      write(line_buf, string'("TIME: ")); write(line_buf, time'image(now)); writeline(log_file, line_buf);

      write(line_buf, string'("STATE_OUT = ")); write(line_buf, to_hex_str(state_out)); writeline(log_file, line_buf);
      write(line_buf, string'("NORM_ADDR = ")); write(line_buf, to_hex_str(std_logic_vector(norm_debug_addr))); writeline(log_file, line_buf);
      write(line_buf, string'("NORM_DATA = ")); write(line_buf, to_hex_str(norm_debug_data)); writeline(log_file, line_buf);
      write(line_buf, string'("NORM_WE = ")); write(line_buf, norm_debug_we); writeline(log_file, line_buf);
      write(line_buf, string'("PP_ADDR = ")); write(line_buf, to_hex_str(std_logic_vector(pp_debug_addr))); writeline(log_file, line_buf);
      write(line_buf, string'("PP_DATA = ")); write(line_buf, to_hex_str(pp_debug_data)); writeline(log_file, line_buf);
      write(line_buf, string'("PP_WE = ")); write(line_buf, pp_debug_we); writeline(log_file, line_buf);
      write(line_buf, string'("DEBUG_START_OUT = ")); write(line_buf, debug_start_out); writeline(log_file, line_buf);
      write(line_buf, string'("DEBUG_UART_ADDR_OUT = ")); write(line_buf, to_hex_str(std_logic_vector(debug_uart_addr_out))); writeline(log_file, line_buf);

      writeline(log_file, line_buf);  -- empty line
    end loop;

    report "Logging during DEBUG...";

    while state_out = "1001" loop
      wait for 100 ns;

      write(line_buf, string'("TIME: ")); write(line_buf, time'image(now)); writeline(log_file, line_buf);

      write(line_buf, string'("PP_ADDR = ")); write(line_buf, to_hex_str(std_logic_vector(pp_debug_addr))); writeline(log_file, line_buf);
      write(line_buf, string'("PP_DATA = ")); write(line_buf, to_hex_str(pp_debug_data)); writeline(log_file, line_buf);
      write(line_buf, string'("PP_WE = ")); write(line_buf, pp_debug_we); writeline(log_file, line_buf);
      write(line_buf, string'("DEBUG_START_OUT = ")); write(line_buf, debug_start_out); writeline(log_file, line_buf);
      write(line_buf, string'("DEBUG_UART_ADDR_OUT = ")); write(line_buf, to_hex_str(std_logic_vector(debug_uart_addr_out))); writeline(log_file, line_buf);

      writeline(log_file, line_buf);  -- empty line
    end loop;
    report "Simulation done";
    wait;
  end process;

end sim;
