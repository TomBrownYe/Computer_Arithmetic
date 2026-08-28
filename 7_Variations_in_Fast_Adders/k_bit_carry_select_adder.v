//本架构参考Fig7.9
`include "carry_propagate_adder_in_7.v"

module k_bit_carry_select_adder #(
   parameter WIDTH = 64//位宽必须要是偶数
) (
    input [WIDTH-1:0] x,
    input [WIDTH-1:0] y,
    input             cin,
    output [WIDTH-1:0] sum,
    output             cout 
);
    localparam HALF_WIDTH = WIDTH/2;
    wire [HALF_WIDTH-1:0] x1, x2, y1, y2;
    wire [HALF_WIDTH-1:0] sum1, sum2_0,sum2_1,sum2;
    wire c_half,cout_0,cout_1;
    
    carry_propagate_adder #(.WIDTH(HALF_WIDTH)) adder1(
        .x(x[HALF_WIDTH-1:0]),
        .y(y[HALF_WIDTH-1:0]),
        .c_in(cin),
        .sum(sum1),
        .c_out(c_half)
    );

    carry_propagate_adder #(.WIDTH(HALF_WIDTH)) adder2(
        .x(x[WIDTH-1:HALF_WIDTH]),
        .y(y[WIDTH-1:HALF_WIDTH]),
        .c_in(1'b0),
        .sum(sum2_0),
        .c_out(cout_0)
    );

    carry_propagate_adder #(.WIDTH(HALF_WIDTH)) adder3(
        .x(x[WIDTH-1:HALF_WIDTH]),
        .y(y[WIDTH-1:HALF_WIDTH]),
        .c_in(1'b1),
        .sum(sum2_1),
        .c_out(cout_1)
    );

    assign sum2 = c_half ? sum2_1 : sum2_0;
    assign sum = {sum2, sum1};

    assign cout = c_half ? cout_1 : cout_0;

endmodule
