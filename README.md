# Pinout

| Type | Name     | Function                                |
|------|----------|-----------------------------------------|
| I    | clk      | board clock                             |
| I    | rst_n    | low to reset                            |
| I    | ena      | will go high when the design is enabled |
|------|----------|-----------------------------------------|
| I    | spi_clk  | main spi clock                          |
| I    | spi_cs   | spi chip select                         |
| I    | spi_mosi | spi secondary in                        |
| I    | f0_clk   | fn0 interpolation group clock           |
| I    | f1_clk   | fn1 interpolation group clock           |
| I    | <?>      |                                         |
| I    | <?>      |                                         |
| I    | <?>      |                                         |
| O    | spi_miso | spi secondary out                       |
| O    | f0_o0    | X                                       |
| O    | f0_o1    | Y                                       |
| O    | f0_o2    | Z                                       |
| O    | f1_o0    | s                                       |
| O    | f2_o1    | t                                       |
| O    | <?>      |                                         |
| O    | <?>      |                                         |
| I/O  | <?>      |                                         |
| I/O  | <?>      |                                         |
| I/O  | <?>      |                                         |
| I/O  | <?>      |                                         |
| I/O  | <?>      |                                         |
| I/O  | <?>      |                                         |
| I/O  | <?>      |                                         |
| I/O  | <?>      |                                         |

Idea: model something like `f0(f1(f2(clk)))`
