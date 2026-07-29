`timescale 1ns / 1ns
`include "base5_to_bin_horner.v"

module tb_base5_to_bin_horner;

reg [2:0] d3, d2, d1, d0;
wire [9:0] bin_out;
reg [9:0] expected_bin_out;
base5_to_bin_horner uut (
    .d3(d3),
    .d2(d2),
    .d1(d1),
    .d0(d0),
    .bin_out(bin_out)
);

initial begin
    d3 = 3'd0; d2 = 3'd0; d1 = 3'd0; d0 = 3'd0; // 0000_5

    #5;

    d3 = 3'd3; d2 = 3'd1; d1 = 3'd0; d0 = 3'd4; // 3104_5
    expected_bin_out = 125*d3 + 25*d2 + 5*d1 + d0; 

    #5;

    if(bin_out != expected_bin_out) begin
        $display("Test failed for input 3104_5: expected %d, got %d", expected_bin_out, bin_out);
    end 
    else begin
        $display("Test passed for input 3104_5: got %d", bin_out);
    end

    #5;

    $finish;

end

endmodule