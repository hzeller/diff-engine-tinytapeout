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

  // XLS-generated core (src/diff_engine.sv, produced from diff_engine.x by `make`).
  //
  // The core's channels carry structs, which XLS flattens with field 0 in the
  // MSBs:  Inputs{ui_in, uio_in} -> 16 bits,  Outputs{uo_out, uio_out, uio_oe}
  // -> 24 bits. Tying valid/ready high makes the core advance once per clock and
  // lets synthesis fold the handshake away.
  wire [23:0] core_out;
  wire in_rdy_unused, out_vld_unused;

  xls_diff_engine diff_engine (
      .clk         (clk),
      .rst_n       (rst_n),
      ._ui_in      ({ui_in, uio_in}),
      ._ui_in_vld  (1'b1),
      ._ui_in_rdy  (in_rdy_unused),
      ._uo_out     (core_out),
      ._uo_out_vld (out_vld_unused),
      ._uo_out_rdy (1'b1)
  );

  assign uo_out  = core_out[23:16];
  assign uio_out = core_out[15:8];
  assign uio_oe  = core_out[7:0];

  // Avoid unused-signal warnings.
  wire _unused = &{ena, in_rdy_unused, out_vld_unused, 1'b0};
endmodule
