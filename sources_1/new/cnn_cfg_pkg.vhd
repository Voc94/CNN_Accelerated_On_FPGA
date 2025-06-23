library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package cnn_cfg_pkg is
  --Fixed point dimensions
  constant Q_INT : integer := 1;
  constant Q_FRAC : integer := 14;
  -- Image dimensions
  constant IMG_WIDTH   : integer := 64;
  constant IMG_HEIGHT  : integer := 64;
  constant IMG_SIZE    : integer := IMG_WIDTH * IMG_HEIGHT;

  -- Data width (e.g., 8-bit grayscale pixels)
  constant DATA_WIDTH  : integer := 8;

  -- Address width needed for addressing image pixels 
  -- !!!!!CHANGE OR LOOK AT IT EVERYTIME YOU CHANGE THE BRAM DEPTH
  constant ADDR_WIDTH  : integer := 13;  -- 2^12 = 4096 (covers 64x64)

  -- UART configuration
  constant CLK_FREQ    : integer := 100_000_000;
  constant BAUD_RATE   : integer := 115200;
  constant CMD_WRITE_IMAGE  : std_logic_vector(7 downto 0) := x"10";
  constant CMD_READ_IMAGE   : std_logic_vector(7 downto 0) := x"20";
  

end package;
