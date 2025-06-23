library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.cnn_cfg_pkg.all;

-- ============================================================================
-- ENTITY: CNN TOP-LEVEL
-- ============================================================================
entity cnn is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    uart_rx  : in  std_logic;
    uart_tx  : out std_logic;
    led      : out std_logic_vector(3 downto 0);
    start    : in  std_logic
  );
end entity;

-- ============================================================================
-- ARCHITECTURE
-- ============================================================================
architecture Structural of cnn is

  ----------------------------------------------------------------------------
  -- TYPES & STATE ENUM
  ----------------------------------------------------------------------------
  type state_t is (
    STATE_INIT,
    STATE_NORMALIZE,
    STATE_CONV1,
    STATE_MAXPOOL1,
    STATE_CONV2,
    STATE_MAXPOOL2,
    STATE_FC1,
    STATE_FC2,
    STATE_WAIT_DEBUG,
    STATE_DEBUG,
    STATE_DONE
  );
  signal state : state_t := STATE_INIT;

  ----------------------------------------------------------------------------
  -- CLOCK DIVIDER SIGNAL
  ----------------------------------------------------------------------------
  signal slow_tick : std_logic;

  ----------------------------------------------------------------------------
  -- SHARED IMAGE BRAM INTERFACE (UART or normalize reads/writes)
  ----------------------------------------------------------------------------
  signal bram_addr     : unsigned(ADDR_WIDTH-1 downto 0);
  signal bram_wr_data  : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal bram_rd_data  : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal bram_we       : std_logic;
  signal wea_sig       : std_logic_vector(0 downto 0);

  ----------------------------------------------------------------------------
  -- UART COMMAND INTERFACE (PC <-> BRAM)
  ----------------------------------------------------------------------------
  signal uart_addr     : unsigned(ADDR_WIDTH-1 downto 0);
  signal uart_wr_data  : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal uart_rd_data  : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal uart_we       : std_logic;

  ----------------------------------------------------------------------------
  -- NORMALIZE <-> IMAGE BRAM INTERFACE
  ----------------------------------------------------------------------------
  signal img_addr      : unsigned(ADDR_WIDTH-1 downto 0);
  signal img_wr_data   : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal img_we        : std_logic;
  signal img_rd_data   : std_logic_vector(DATA_WIDTH-1 downto 0);

  ----------------------------------------------------------------------------
  -- NORMALIZE <-> PING-PONG BRAM INTERFACE
  ----------------------------------------------------------------------------
  signal norm_addr     : unsigned(14 downto 0);
  signal norm_wr_data  : std_logic_vector(15 downto 0);
  signal norm_rd_data  : std_logic_vector(15 downto 0);
  signal norm_we       : std_logic;
  signal norm_start    : std_logic := '0';
  signal norm_done     : std_logic;

  ----------------------------------------------------------------------------
  -- DEBUG <-> PING-PONG BRAM INTERFACE
  ----------------------------------------------------------------------------
  signal pp_addr       : unsigned(14 downto 0);
  signal pp_wr_data    : std_logic_vector(15 downto 0);
  signal pp_rd_data    : std_logic_vector(15 downto 0);
  signal pp_we         : std_logic;

  ----------------------------------------------------------------------------
  -- UART DEBUG MODULE SIGNALS
  ----------------------------------------------------------------------------
  signal debug_tx         : std_logic;
  signal start_debug      : std_logic := '0';
  signal uart_cmd_tx      : std_logic;
  signal uart_debug_addr  : unsigned(14 downto 0);
  signal debug_rx, cmd_rx : std_logic;

  ----------------------------------------------------------------------------
  -- LED REGISTER
  ----------------------------------------------------------------------------
  signal led_reg : std_logic_vector(3 downto 0);

begin

  ----------------------------------------------------------------------------
  -- CLOCK DIVIDER
  ----------------------------------------------------------------------------
  clk_div_inst : entity work.clk_divider
    generic map ( WIDTH => 20 )
    port map (
      clk       => clk,
      rst       => rst,
      slow_tick => slow_tick
    );

  ----------------------------------------------------------------------------
  -- UART COMMAND MODULE (for PC communication)
  ----------------------------------------------------------------------------
  uart_cmd_inst: entity work.uart_cmd
    port map (
      clk           => clk,
      rst           => rst,
      uart_rx       => cmd_rx,
      uart_tx       => uart_cmd_tx,
      led           => open,
      bram_we       => uart_we,
      bram_wr_data  => uart_wr_data,
      bram_rd_data  => uart_rd_data,
      bram_addr     => uart_addr
    );

  ----------------------------------------------------------------------------
  -- IMAGE BRAM (shared between UART and normalize)
  ----------------------------------------------------------------------------
  wea_sig(0) <= bram_we;

  image_bram_inst: entity work.blk_mem_gen_0
    port map (
      clka   => clk,
      ena    => '1',
      wea    => wea_sig,
      addra  => std_logic_vector(bram_addr),
      dina   => bram_wr_data,
      douta  => bram_rd_data
    );

  ----------------------------------------------------------------------------
  -- PING-PONG BRAM (written by normalize, read by debug)
  ----------------------------------------------------------------------------
  ping_pong_bram_inst: entity work.simple_bram
    generic map (
      DATA_WIDTH => 16,
      ADDR_WIDTH => 15
    )
    port map (
      clk   => clk,
      we    => pp_we,
      addr  => pp_addr,
      din   => pp_wr_data,
      dout  => pp_rd_data
    );

  ----------------------------------------------------------------------------
  -- IMAGE NORMALIZATION MODULE
  ----------------------------------------------------------------------------
  img_normalize_inst: entity work.img_normalize
    generic map (
      G_IMG_W             => 64,
      G_IMG_H             => 64,
      IMG_BRAM_ADDR       => 13,
      IMG_BRAM_WIDTH      => 8,
      PING_PONG_BRAM_ADDR => 15,
      PING_PONG_BRAM_WIDTH=> 16
    )
    port map (
      clk             => clk,
      rst             => rst,
      start           => norm_start,
      done            => norm_done,
      img_addr        => img_addr,
      img_din         => open,
      img_dout        => img_rd_data,
      img_we          => img_we,
      ping_pong_addr  => norm_addr,
      ping_pong_din   => norm_wr_data,
      ping_pong_dout  => norm_rd_data,
      ping_pong_we    => norm_we
    );

  ----------------------------------------------------------------------------
  -- UART DEBUG MODULE
  ----------------------------------------------------------------------------
  uart_debug_inst: entity work.uart_debug
    generic map (
      ADDR_WIDTH => 15,
      DATA_WIDTH => 16
    )
    port map (
      clk           => clk,
      rst           => rst,
      uart_rx       => debug_rx,
      uart_tx       => debug_tx,
      start_read    => start_debug,
      num_addresses => 4096,
      bram_addr     => uart_debug_addr,
      bram_rd_data  => pp_rd_data
    );

  ----------------------------------------------------------------------------
  -- MAIN FSM: Controls normalize and debug
  ----------------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state <= STATE_INIT;
      else
        norm_start  <= '0';
        start_debug <= '0';

        case state is
          when STATE_INIT =>
            if start = '1' then
              norm_start <= '1';
              state <= STATE_NORMALIZE;
            end if;

          when STATE_NORMALIZE =>
            if norm_done = '1' then
              state <= STATE;
            end if;

          when STATE_WAIT_DEBUG =>
            if start = '0' then
              state <= STATE_DEBUG;
            end if;

          when STATE_DEBUG =>
            start_debug <= '1';

          when others =>
            state <= STATE_INIT;
        end case;
      end if;
    end if;
  end process;

  ----------------------------------------------------------------------------
  -- LED DRIVER (visualizes FSM state with slow tick)
  ----------------------------------------------------------------------------
  led_driver : process(clk, rst)
  begin
    if rst = '1' then
      led_reg <= "0001";
    elsif rising_edge(clk) then
      if slow_tick = '1' then
        case state is
          when STATE_INIT       => led_reg <= "0010";
          when STATE_NORMALIZE  => led_reg <= "0100";
          when STATE_DEBUG      => led_reg <= "1000";
          when others           => led_reg <= "0000";
        end case;
      end if;
    end if;
  end process;

  led <= led_reg;

  ----------------------------------------------------------------------------
  -- IMAGE BRAM MUX: UART vs Normalization access
  ----------------------------------------------------------------------------
  bram_mux : process(state, uart_addr, uart_wr_data, uart_we,
                     img_addr, img_wr_data, img_we)
  begin
    bram_we      <= uart_we;
    bram_wr_data <= uart_wr_data;
    bram_addr    <= uart_addr;
    if state = STATE_NORMALIZE then
      bram_addr    <= img_addr;
      bram_wr_data <= img_wr_data;
      bram_we      <= img_we;
    end if;
  end process;

  ----------------------------------------------------------------------------
  -- PING-PONG BRAM MUX: Normalization vs Debug access
  ----------------------------------------------------------------------------
  ping_pong_mux : process(state, norm_addr, uart_debug_addr)
  begin
    pp_we <= '0';
    if state = STATE_NORMALIZE then
      pp_addr    <= norm_addr;
      pp_wr_data <= norm_wr_data;
      pp_we      <= norm_we;
    elsif state = STATE_DEBUG then
      pp_addr <= uart_debug_addr;
    else
      pp_addr <= (others => '0');
    end if;
  end process;

  ----------------------------------------------------------------------------
  -- SIGNAL ASSIGNMENTS: Routing and wiring
  ----------------------------------------------------------------------------
  cmd_rx        <= uart_rx;
  debug_rx      <= uart_rx;
  uart_rd_data  <= bram_rd_data;
  img_rd_data   <= bram_rd_data;
  norm_rd_data  <= pp_rd_data;

  ----------------------------------------------------------------------------
  -- UART TX MUX: Switch between command UART and debug UART
  ----------------------------------------------------------------------------
  debug_mux : process(state, debug_tx, uart_cmd_tx)
  begin
    uart_tx <= uart_cmd_tx;
    if state = STATE_DEBUG then
      uart_tx <= debug_tx;
    end if;
  end process;

end architecture;
