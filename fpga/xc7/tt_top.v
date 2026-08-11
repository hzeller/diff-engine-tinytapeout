// Arty A7-35 harness for the Tiny Tapeout wrapper (tt_um_lromor_xls).
//
//   ui_in[3:0]  <- sw[3:0]       (slide switches)
//   ui_in[7:4]  <- btn[3:0]      (push buttons, pressed = 1)
//   uo_out[3:0] -> led[3:0]      (green LEDs)
//   uo_out[7:4] -> led_g[3:0]    (green channel of the RGB LEDs)
//   uio_in      <- jc[7:0]       (Pmod JC)
//   uio_out     -> jb[7:0]       (Pmod JB)
//   uio_oe      -> jd[7:0]       (Pmod JD, shows the direction the core set)
//   rst_n       <- ck_rst        (red RESET button, active low)
//   clk         <- 100 MHz oscillator (BUFG auto-inserted by synth)
module top (
    input        clk,
    input        ck_rst,
    input  [3:0] sw,
    input  [3:0] btn,
    output [3:0] led,
    output [3:0] led_g,
    output [7:0] jb,
    input  [7:0] jc,
    output [7:0] jd
);
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  tt_um_lromor_xls tt (
      .clk    (clk),
      .rst_n  (ck_rst),
      .ena    (1'b1),
      .ui_in  ({btn, sw}),
      .uo_out (uo_out),
      .uio_in (jc),
      .uio_out(uio_out),
      .uio_oe (uio_oe)
  );

  assign led   = uo_out[3:0];
  assign led_g = uo_out[7:4];
  assign jb    = uio_out;
  assign jd    = uio_oe;
endmodule
