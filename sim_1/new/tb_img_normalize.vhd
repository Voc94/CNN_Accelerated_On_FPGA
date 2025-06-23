library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;

use work.fixed_float_types.all;
use work.fixed_pkg.all;
use work.cnn_cfg_pkg.all;

entity tb_img_normalize is
end entity;

architecture sim of tb_img_normalize is
  constant IMG_W : integer := 2;
  constant IMG_H : integer := 2;

  -- Signals
  signal clk         : std_logic := '0';
  signal rst         : std_logic := '1';
  signal start       : std_logic := '0';
  signal done        : std_logic;

  signal bram_addr   : unsigned(ADDR_WIDTH-1 downto 0);
  signal bram_din    : std_logic_vector(7 downto 0);
  signal bram_dout   : std_logic_vector(7 downto 0);
  signal bram_we     : std_logic;

  -- Delayed address and write enable (for 2-cycle latency)
  signal bram_addr_d1, bram_addr_d2 : unsigned(ADDR_WIDTH-1 downto 0);
  signal bram_we_d1, bram_we_d2     : std_logic;
  signal bram_din_d1, bram_din_d2   : std_logic_vector(7 downto 0);

  type mem_type is array (0 to 2*IMG_W*IMG_H + 3) of std_logic_vector(7 downto 0);
signal bram_mem : mem_type := (
  x"00",  -- pixel 0 = 0
  x"7F",  -- pixel 1 ≈ 50%
  x"80",  -- pixel 2 ≈ 50% + 1
  x"C0",  -- pixel 3 ≈ 75%
  x"FE",  -- pixel 4 ≈ almost white
  x"FF",  -- pixel 5 = white
  x"01",  -- pixel 6 = very low value
  x"20",  -- pixel 7 = low-mid
  others => (others => '0')
);


  -- Output file
  file outfile : text open write_mode is "normalized_out.txt";

begin

  -- DUT
  uut: entity work.img_normalize
    generic map (
      G_IMG_W     => IMG_W,
      G_IMG_H     => IMG_H,
      G_INT_BITS  => Q_INT,
      G_FRAC_BITS => Q_FRAC
    )
    port map (
      clk        => clk,
      rst        => rst,
      start      => start,
      done       => done,
      bram_addr  => bram_addr,
      bram_din   => bram_din,
      bram_dout  => bram_dout,
      bram_we    => bram_we
    );

  -- Clock generation
  clk_process: process
  begin
    while true loop
      clk <= '0'; wait for 5 ns;
      clk <= '1'; wait for 5 ns;
    end loop;
  end process;

  -- BRAM behavior with 2-cycle latency
  -- BRAM behavior with 2-cycle latency + logging
  bram_proc: process(clk)
    variable L : line;
    variable cycle_counter : integer := 0;
  begin
    if rising_edge(clk) then
      -- Delay address and write enable
      bram_addr_d1 <= bram_addr;
      bram_addr_d2 <= bram_addr_d1;

      bram_we_d1   <= bram_we;
      bram_we_d2   <= bram_we_d1;

      bram_din_d1  <= bram_din;
      bram_din_d2  <= bram_din_d1;

      -- Simulated read (2-cycle delayed)
      bram_dout <= bram_mem(to_integer(bram_addr_d2));

      -- Write (2-cycle delayed)
      if bram_we_d2 = '1' then
        bram_mem(to_integer(bram_addr_d2)) <= bram_din_d2;

        -- Log write
        write(L, string'("WRITE @ time "));
        write(L, now);
        write(L, string'(": addr="));
        write(L, to_integer(bram_addr_d2));
        write(L, string'(" data=0x"));
        hwrite(L, bram_din_d2);
        writeline(outfile, L);
      end if;

      -- Log general info every 50 ns (adjust by counting cycles)
      cycle_counter := cycle_counter + 1;
      if cycle_counter = 5 then  -- 5 * 10 ns = 50 ns
        cycle_counter := 0;

        write(L, string'("==== Time: "));
        write(L, now);
        write(L, string'(" ===="));
        writeline(outfile, L);

        write(L, string'("Read Addr = "));
        write(L, to_integer(bram_addr_d2));
        write(L, string'(" | Data = 0x"));
        hwrite(L, bram_mem(to_integer(bram_addr_d2)));
        writeline(outfile, L);

        write(L, string'("Write Enable (delayed) = "));
        write(L, bram_we_d2);
        writeline(outfile, L);

        write(L, string'("Done signal = "));
        write(L, done);
        writeline(outfile, L);

        write(L, string'("First 8 BRAM bytes: "));
        for i in 0 to 7 loop
          hwrite(L, bram_mem(i));
          write(L, string'(" "));
        end loop;
        writeline(outfile, L);
      end if;
    end if;
  end process;


  -- Stimulus
  stim_proc: process
  begin
    wait for 20 ns;
    rst <= '0';
    wait for 20 ns;
    start <= '1';
    wait for 10 ns;
    start <= '0';

    wait until done = '1';
    wait for 50 ns;

    file_close(outfile);
    report "Normalization test completed." severity note;
    wait;
  end process;

end architecture;
