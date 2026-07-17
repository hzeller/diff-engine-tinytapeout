`default_nettype none

module tt_um_lromor_xls (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // XLS-generated core (src/main.sv, produced from main.x by `make`).
  xls_main core (
      .clk  (clk),
      .rst_n(rst_n),
      .a    (ui_in[3:0]),
      .b    (ui_in[7:4]),
      .out  (uo_out)
  );

  // Bidirectional pins unused.
  assign uio_out = 8'b0;
  assign uio_oe  = 8'b0;

  // Avoid unused-signal warnings.
  wire _unused = &{ena, uio_in, 1'b0};

endmodule
