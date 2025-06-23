library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library ieee_proposed;
use ieee_proposed.fixed_pkg.all;

entity conv_mac is
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
end entity;

architecture Behavioral of conv_mac is
  -- Fixed-point subtypes
  subtype q14_t     is sfixed(1 downto -14);      -- Q1.14 input
  subtype product_t is sfixed(3 downto -28);      -- 16x16 = 32-bit result
  subtype accum_t   is sfixed(3 downto -28);      -- Extra MSB for safe accumulation

  type q14_array_t is array(0 to 8) of q14_t;

  signal done_reg : std_logic := '0';

begin

  process(clk)
    variable acc_v    : accum_t;
    variable partial  : product_t;
    variable x_arr    : q14_array_t;
    variable w_arr    : q14_array_t;
    variable bias_q   : q14_t;
    variable trimmed  : q14_t;
  begin
    if rising_edge(clk) then
      if rst = '1' then
        result   <= (others => '0');
        done_reg <= '0';

      elsif enable = '1' then
        -- Unpack inputs
        for i in 0 to 8 loop
          x_arr(i) := to_sfixed(signed(x((i+1)*16-1 downto i*16)), 1, -14);
          w_arr(i) := to_sfixed(signed(w((i+1)*16-1 downto i*16)), 1, -14);
        end loop;
        bias_q := to_sfixed(signed(bias), 1, -14);

        -- MAC operation
        acc_v := (others => '0');
        for i in 0 to 8 loop
          partial := x_arr(i) * w_arr(i);
          acc_v := resize((acc_v + resize(partial, acc_v'high, acc_v'low)),acc_v'high,acc_v'low);
        end loop;

        -- Add bias
        acc_v := resize(acc_v + resize(bias_q, acc_v'high, acc_v'low),acc_v'high,acc_v'low);

        -- Trim result back to Q1.14
        trimmed := resize(acc_v, 1, -14);
        result  <= to_slv(trimmed);
        done_reg <= '1';

      else
        done_reg <= '0';
      end if;
    end if;
  end process;

  done <= done_reg;
end Behavioral;
