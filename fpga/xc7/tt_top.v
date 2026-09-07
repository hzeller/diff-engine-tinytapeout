// Arty A7-35 harness for the Tiny Tapeout wrapper (tt_um_diff_engine).
//
// Pin roles follow top.x:
//   ui_in[0] <- spi_sclk   JA7  (D13)   BeagleBone P9_31 (SPI1_SCLK)
//   ui_in[1] <- spi_cs     JA1  (G13)   BeagleBone P9_28 (SPI1_CS0), active low
//   ui_in[2] <- spi_mosi   JA2  (B11)   BeagleBone P9_30 (SPI1_D1)
//   ui_in[3] <- poly_clk   JB7  (J17)   BeagleBone P9_17, sample on rising edge
//   uo_out[0] -> spi_miso  JA8  (B18)   BeagleBone P9_29 (SPI1_D0)
//   uo_out[1] -> step      JB1  (E15)   BeagleBone P9_18
//   uo_out[2] -> dir       JB2  (E16)
//   led[3:0] = {spi_cs, poly_clk, dir, step}
//   rst_n   <- power-on reset (first ~650 us after configuration) AND ck_rst button
//   clk     <- 100 MHz oscillator
//
// Debug: 6-byte telemetry frames on the USB UART (115200 8N1) every ~1.3 ms:
//   A5 <ui_in> <uo_out> <step toggles> <poly_clk rising edges> <frame#>
module top (
    input        clk,
    input        ck_rst,
    input        spi_sclk,
    input        spi_cs,
    input        spi_mosi,
    input        poly_clk,
    output       spi_miso,
    output       step,
    output       dir,
    output       uart_tx,
    output [3:0] led
);
  (* keep *) reg clk_alive = 1'b0;
  always @(posedge clk) clk_alive <= ~clk_alive;

  // Power-on reset: hold rst_n low for 2^16 cycles after configuration.
  reg [16:0] por = 17'd0;
  always @(posedge clk) if (!por[16]) por <= por + 17'd1;
  wire rst_n = por[16] & ck_rst;

  // Synchronize the asynchronous board inputs.
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
  assign led      = {in_s1[1], in_s1[3], uo_out[2], uo_out[1]};

  // Event counters for the telemetry.
  reg [7:0] step_cnt = 8'd0, poly_cnt = 8'd0;
  reg       step_d = 1'b0, poly_d = 1'b0;
  always @(posedge clk) begin
    step_d <= uo_out[1];
    poly_d <= in_s1[3];
    if (uo_out[1] != step_d) step_cnt <= step_cnt + 8'd1;
    if (in_s1[3] & ~poly_d) poly_cnt <= poly_cnt + 8'd1;
  end

  // Telemetry: 6 bytes per frame.
  reg [16:0] tick = 17'd0;
  reg [7:0]  frame = 8'd0;
  reg [2:0]  idx = 3'd6;           // 6 = idle
  reg [7:0]  s_ui = 8'd0, s_uo = 8'd0, s_step = 8'd0, s_poly = 8'd0;
  reg        start = 1'b0;
  reg [7:0]  data = 8'd0;
  wire       busy;
  uart_tx u (.clk(clk), .data(data), .start(start), .tx(uart_tx), .busy(busy));
  always @(posedge clk) begin
    start <= 1'b0;
    tick  <= tick + 17'd1;
    if (tick == 17'd0 && idx == 3'd6) begin
      s_ui <= ui_in; s_uo <= uo_out; s_step <= step_cnt; s_poly <= poly_cnt; idx <= 3'd0;
    end else if (idx != 3'd6 && !busy && !start) begin
      case (idx)
        3'd0: data <= 8'hA5;
        3'd1: data <= s_ui;
        3'd2: data <= s_uo;
        3'd3: data <= s_step;
        3'd4: data <= s_poly;
        default: data <= frame;
      endcase
      start <= 1'b1;
      if (idx == 3'd5) frame <= frame + 8'd1;
      idx <= idx + 3'd1;
    end
  end
endmodule
