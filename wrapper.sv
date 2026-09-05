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
  // Handshake outputs we do not use; declared because `default_nettype none.
  wire ui_in_rdy_unused, uo_out_vld_unused;

  xls_diff_engine diff_engine (
      .clk         (clk),
      .rst_n       (rst_n),
      ._ui_in      (ui_in),
      ._ui_in_vld  (1'b1),
      ._ui_in_rdy  (ui_in_rdy_unused),
      ._uo_out     (uo_out),
      ._uo_out_vld (uo_out_vld_unused),
      ._uo_out_rdy (1'b1)
  );

  assign uio_out = 8'h00;
  assign uio_oe  = 8'h00;

  wire _unused = &{ena, uio_in, ui_in_rdy_unused, uo_out_vld_unused, 1'b0};
endmodule
