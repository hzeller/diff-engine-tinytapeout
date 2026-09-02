`default_nettype none

module tt_um_lromor_xls (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // XLS-generated core (src/main.sv, produced from main.x by `make`).
  wire [23:0] core_out;

  xls_spi spi (
      .clk   (clk),
      .rst_n (rst_n),
      .ui_in (ui_in),
      .uio_in(uio_in),
      .out   (core_out)
  );

  xls_diff_engine diff_engine (
      .clk   (clk),
      .rst_n (rst_n),
      .ui_in (ui_in),
      .uio_in(uio_in),
      .out   (core_out)
  );

  // DSLX tuple (uo_out, uio_out, uio_oe): element 0 lands in the MSBs.
  assign uo_out  = core_out[23:16];
  assign uio_out = core_out[15:8];
  assign uio_oe  = core_out[7:0];

  // Avoid unused-signal warnings.
  wire _unused = &{ena, 1'b0};
endmodule
