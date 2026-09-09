// TinyFPGA BX (iCE40 LP8K) harness for the Tiny Tapeout wrapper (tt_um_diff_engine).
// Same pin roles as the Arty harness (fpga/xc7/tt_top.v), 16 MHz clock, no UART.
//
//   ui_in[0] <- spi_sclk   PIN_1 (A2)
//   ui_in[1] <- spi_cs     PIN_2 (A1)   active low
//   ui_in[2] <- spi_mosi   PIN_3 (B1)
//   ui_in[3] <- poly_clk   PIN_5 (C1)   sample on rising edge
//   uo_out[0] -> spi_miso  PIN_4 (C2)
//   uo_out[1] -> step      PIN_6 (D2)
//   uo_out[2] -> dir       PIN_7 (D1)
//   led       =  step
//   rst_n     <- power-on reset (first 2^14 clocks after configuration)
//   usbpu     =  0  (keep the USB pull-up off so the host does not see a device)
module top (
    input  clk,
    input  spi_sclk,
    input  spi_cs,
    input  spi_mosi,
    input  poly_clk,
    output spi_miso,
    output step,
    output dir,
    output led,
    output usbpu
);
  assign usbpu = 1'b0;

  reg [14:0] por = 15'd0;
  always @(posedge clk) if (!por[14]) por <= por + 15'd1;
  wire rst_n = por[14];

  reg [3:0] in_s0 = 4'd0, in_s1 = 4'd0;
  always @(posedge clk) begin
    in_s0 <= {poly_clk, spi_mosi, spi_cs, spi_sclk};
    in_s1 <= in_s0;
  end
  wire [7:0] ui_in = {4'b0000, in_s1};

  wire [7:0] uo_out, uio_out, uio_oe;
  tt_um_diff_engine tt (
      .clk    (clk),
      .rst_n  (rst_n),
      .ena    (1'b1),
      .ui_in  (ui_in),
      .uo_out (uo_out),
      .uio_in (8'b0),
      .uio_out(uio_out),
      .uio_oe (uio_oe)
  );
  assign spi_miso = uo_out[0];
  assign step     = uo_out[1];
  assign dir      = uo_out[2];
  assign led      = uo_out[1];
endmodule
