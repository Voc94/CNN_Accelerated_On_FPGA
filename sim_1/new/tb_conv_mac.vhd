library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
entity tb_conv_mac is
end entity;

architecture sim of tb_conv_mac is

  -- Component declaration
  component conv_mac is
    port (
      clk    : in  std_logic;
      rst    : in  std_logic;
      enable : in  std_logic;
      x      : in  std_logic_vector(9*16-1 downto 0);
      w      : in  std_logic_vector(9*16-1 downto 0);
      bias   : in  std_logic_vector(15 downto 0);
      result : out std_logic_vector(15 downto 0);
      done   : out std_logic
    );
  end component;

  -- Signals
  signal clk    : std_logic := '0';
  signal rst    : std_logic := '1';
  signal enable : std_logic := '0';

  signal x      : std_logic_vector(9*16-1 downto 0) := (others => '0');
  signal w      : std_logic_vector(9*16-1 downto 0) := (others => '0');
  signal bias   : std_logic_vector(15 downto 0) := (others => '0');
  signal result : std_logic_vector(15 downto 0);
  signal done   : std_logic;

  -- Clock period
  constant clk_period : time := 10 ns;

begin

  -- DUT Instantiation
  uut: conv_mac
    port map (
      clk     => clk,
      rst     => rst,
      enable  => enable,
      x       => x,
      w       => w,
      bias    => bias,
      result  => result,
      done    => done
    );

  -- Clock generation
  clk_process : process
  begin
    clk <= '0';
    wait for clk_period/2;
    clk <= '1';
    wait for clk_period/2;
  end process;

  -- Stimulus process
  stim_proc: process
    variable x_val : std_logic_vector(15 downto 0);
    variable w_val : std_logic_vector(15 downto 0);
  begin
    -- Wait for global reset
    wait for 20 ns;
    rst <= '0';

    -- Simple test case: all x = 0.5 (0x2000), all w = 1.0 (0x4000), bias = 0.25 (0x1000)
    x_val := x"2000"; -- Q1.14 for 0.5
    w_val := x"4000"; -- Q1.14 for 1.0

    -- Fill x and w with repeated values
    for i in 0 to 8 loop
      x((i+1)*16-1 downto i*16) <= x_val;
      w((i+1)*16-1 downto i*16) <= w_val;
    end loop;

    bias <= x"1000";  -- 0.25 in Q1.14

    wait for clk_period;
    enable <= '1';
    wait for clk_period;
    enable <= '0';

    -- Wait for done
    wait until done = '1';
    wait for clk_period;

    -- Show result
    report "Result 1 (0.5*1.0*9 + 0.25) should be approx 4.75 Q1.14";

    -- Another test case: all x = 1.0 (0x4000), w = 1.0, bias = 0
    for i in 0 to 8 loop
      x((i+1)*16-1 downto i*16) <= x"4000";
      w((i+1)*16-1 downto i*16) <= x"4000";
    end loop;
    bias <= x"0000";  -- 0.0

    wait for clk_period;
    enable <= '1';
    wait for clk_period;
    enable <= '0';

    wait until done = '1';
    wait for clk_period;

    report "Result 2 (1.0*1.0*9) = 9.0 Q1.14, expect result = 0x9000";

    -- End sim
    wait;
  end process;

end architecture;
