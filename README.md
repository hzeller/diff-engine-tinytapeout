# Difference engine on Tiny Tapeout

A cubic polynomial sampler with an SPI request interface and a step/dir output for stepper
motor drivers. The design is written in DSLX and compiled to Verilog with
[google/xls](https://github.com/google/xls). See `docs/info.md` for the request format, the
output encoding and the protocol.

## Pinout

| Pin       | Dir | Name       | Function                                   |
|-----------|-----|------------|--------------------------------------------|
| `ui_in[0]` | I  | `SPI_SCLK` | SPI clock, data is sampled on the rising edge |
| `ui_in[1]` | I  | `SPI_CS_N` | SPI chip select, active low                |
| `ui_in[2]` | I  | `SPI_MOSI` | SPI data in, bit 63 of the request first   |
| `ui_in[3]` | I  | `POLY_CLK` | one sample per rising edge                 |
| `uo_out[0]` | O | `SPI_MISO` | always 0                                   |
| `uo_out[1]` | O | `STEP`     | bit 10 of the sample value                 |
| `uo_out[2]` | O | `DIR`      | 0 = value increases, 1 = value decreases   |

All other pins are unused. `uio` pins are inputs.

## Build the Verilog

The DSLX sources are in the repository root. `src/` is generated and not tracked.

```
nix develop --command make          # top.x -> src/top.sv, wrapper.sv -> src/project.sv
nix develop --command make test     # DSLX tests
```

`make` only tracks `top.x`. After you change `spi.x` or `iterative_polynomial_sampler.x`, run
`rm -f top.ir top.opt.ir src/top.sv` before `make`.

## Run on an Arty A7-35

The harness is in `fpga/xc7/`. It runs the core at 100 MHz and sends a telemetry stream on the
USB UART (115200 8N1): every 1.3 ms one frame `A5 <ui_in> <uo_out> <step toggles> <poly edges> <frame>`.

```
nix develop .#xc7 --command make -C fpga/xc7 all upload
```

| Signal     | Pmod pin | FPGA ball |
|------------|----------|-----------|
| `SPI_CS_N` | JA1      | G13       |
| `SPI_MOSI` | JA2      | B11       |
| `SPI_SCLK` | JA7      | D13       |
| `SPI_MISO` | JA8      | B18       |
| `STEP`     | JB1      | E15       |
| `DIR`      | JB2      | E16       |
| `POLY_CLK` | JB7      | J17       |

The LEDs show `STEP`, `DIR`, `POLY_CLK` and `SPI_CS_N`. The `RESET` button resets the core.

The bitstream assembler needs the fix from
[fpga-assembler#46](https://github.com/lromor/fpga-assembler/pull/46) for pins in `SING` IO
tiles (JA1, JA10). Until the flake input points at a release with that fix, pass your own build:

```
nix develop .#xc7 --command make -C fpga/xc7 all upload FPGA_AS=/path/to/fpga-as
```

## Run on a TinyFPGA BX

The harness is in `fpga/ice40/`. It runs the core at 16 MHz. There is no UART on this board.
The user LED shows `STEP`.

```
nix develop .#ice40 --command make -C fpga/ice40 all       # yosys -> nextpnr-ice40 -> icepack
nix develop .#ice40 --command make -C fpga/ice40 upload    # tinyprog, press the reset button first
```

| Signal     | Board pin | FPGA ball |
|------------|-----------|-----------|
| `SPI_SCLK` | PIN_1     | A2        |
| `SPI_CS_N` | PIN_2     | A1        |
| `SPI_MOSI` | PIN_3     | B1        |
| `SPI_MISO` | PIN_4     | C2        |
| `POLY_CLK` | PIN_5     | C1        |
| `STEP`     | PIN_6     | D2        |
| `DIR`      | PIN_7     | D1        |

## Drive it from a Linux board

Any SPI master with one spare output pin works. With a BeagleBone or a Raspberry Pi you can
bit-bang all pins from Python with libgpiod:

1. Set `SPI_CS_N` low.
2. For each of the 64 request bits, bit 63 first: set `SPI_MOSI`, then pulse `SPI_SCLK` high and low.
3. Set `SPI_CS_N` high.
4. Pulse `POLY_CLK` once per sample and read `STEP` and `DIR` after each pulse.

Example request: `r0 = 0, r1 = -30, r2 = 420, r3 = -1800, count = 26`. `STEP` rises after
tick 2, falls after tick 5, rises after tick 21 (`DIR` goes to 1 first) and falls after tick 24.

## Tiny Tapeout

`info.yaml` and `docs/info.md` hold the datasheet content. The `gds` and `docs` workflows run on
every push. The design fits a 1x1 tile with the current 12-bit registers and 16-bit count.
