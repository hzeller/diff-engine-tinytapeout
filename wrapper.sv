`default_nettype none

module tt_um_lromor_xls (
    // Inputs
    input  wire       clk,      // clock
    input  wire       rst_n,    // reset, active low
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire [7:0] ui_in,    // dedicated inputs

    // Outputs
    output wire [7:0] uo_out,   // dedicated outputs

    // Bidirectional pins
    input  wire [7:0] uio_in,   // input path
    output wire [7:0] uio_out,  // output path
    output wire [7:0] uio_oe    // enable path (active high: 0=input, 1=output)
);

  // XLS-generated core (src/main.sv, produced from main.x by `make`).
  wire [23:0] core_out;

  xls_main core (
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
