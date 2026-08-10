// Smoke-test design: free-running counter, top bits out.
module top (
    input  clk,
    output [3:0] led
);
  reg [23:0] counter = 0;

  always @(posedge clk) counter <= counter + 1;

  assign led = counter[23:20];
endmodule
