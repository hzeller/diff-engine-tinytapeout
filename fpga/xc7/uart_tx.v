// Minimal 8N1 UART transmitter. DIV = clk / baud (100 MHz / 115200 = 868).
module uart_tx #(parameter DIV = 868) (
    input        clk,
    input  [7:0] data,
    input        start,
    output reg   tx   = 1'b1,
    output reg   busy = 1'b0
);
  reg [8:0]  shift = 9'h1ff;
  reg [3:0]  bits  = 4'd0;
  reg [15:0] cnt   = 16'd0;
  always @(posedge clk) begin
    if (!busy) begin
      if (start) begin
        tx <= 1'b0; shift <= {1'b1, data}; bits <= 4'd9; cnt <= 16'd0; busy <= 1'b1;
      end
    end else if (cnt == DIV - 1) begin
      cnt <= 16'd0;
      if (bits == 4'd0) busy <= 1'b0;
      else begin tx <= shift[0]; shift <= {1'b1, shift[8:1]}; bits <= bits - 4'd1; end
    end else cnt <= cnt + 16'd1;
  end
endmodule
