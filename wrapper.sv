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
