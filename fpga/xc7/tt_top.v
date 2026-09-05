// Arty A7-35 harness for the Tiny Tapeout wrapper (tt_um_lromor_xls).
//
// Minimal pinout: only the top two core inputs and the top two core outputs
// are brought to the board.
//
//   ui_in[7:6]  <- btn[1:0]      (push buttons, pressed = 1)
//   ui_in[5:0]  <- 0
//   uo_out[7:6] -> led[1:0]      (green LEDs)
//   uio_in      <- 0             (bidirectionals unused)
//   rst_n       <- ck_rst        (red RESET button, active low)
//   clk         <- 100 MHz oscillator (BUFG auto-inserted by synth)
module top (
    input        clk,
    input        ck_rst,
    input  [1:0] btn,
    output [1:0] led
);
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  tt_um_lromor_xls tt (
      .clk    (clk),
      .rst_n  (ck_rst),
      .ena    (1'b1),
      .ui_in  ({btn, 6'b0}),
      .uo_out (uo_out),
      .uio_in (8'b0),
      .uio_out(uio_out),
      .uio_oe (uio_oe)
  );

  assign led = uo_out[7:6];
endmodule
