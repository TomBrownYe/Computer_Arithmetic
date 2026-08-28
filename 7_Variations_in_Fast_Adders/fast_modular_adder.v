//本架构参见Fig7.15
`include"carry_save_adder_in_7.v"

module fast_modular_adder #(
    parameter WIDTH = 32
)(
    input  wire [WIDTH - 1 : 0] x,
    input  wire [WIDTH - 1 : 0] y,
    input  wire [WIDTH - 1 : 0] m,
    output wire [WIDTH - 1 : 0] mod_sum
);
    wire [WIDTH - 1 : 0] sum1 = x + y;

    wire [WIDTH - 1 : 0] sum2_tmp;
    wire [WIDTH - 1 : 0] carry2;
    carry_save_adder #(.WIDTH(WIDTH)) uuu1(
        .x(x),
        .y(y),
        .z(~m),
        .sum(sum2_tmp),
        .carry(carry2)
    );
    wire sign_bit;
    wire [WIDTH - 1 : 0] sum2;
    assign {sign_bit, sum2} = sum2_tmp + (carry2<<1) + 1'b1;

    assign mod_sum = sign_bit ? sum2 : sum1;
endmodule