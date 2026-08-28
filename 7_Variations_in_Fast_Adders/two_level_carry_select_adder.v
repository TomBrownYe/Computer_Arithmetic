//本架构参见Fig7.10
`include "carry_propagate_adder_in_7.v"

module two_level_carry_select_adder #(
    parameter WIDTH = 64 //位宽必须要是4的倍数
)(
    input [WIDTH-1:0] x,
    input [WIDTH-1:0] y,
    input             cin,
    output [WIDTH-1:0] sum,
    output             cout 
);
    localparam MOD_WIDTH = WIDTH / 4;
    
    wire [MOD_WIDTH-1:0] x0,x1,x2,x3,y0,y1,y2,y3;
    wire [MOD_WIDTH-1:0] sum0,sum1_0,sum1_1,sum1,sum2_0,sum2_1,sum2,sum3_0,sum3_1,sum3_real1,sum3_real0;
    wire                 cout0,cout1_0,cout1_1,cout1,cout2_0,cout2_1,cout3_0,cout3_1,cout3_real0,cout3_real1;
    wire [2*MOD_WIDTH-1:0] sum_high;
    assign x0 = x[MOD_WIDTH-1:0];
    assign x1  = x[2*MOD_WIDTH-1:MOD_WIDTH];
    assign x2  = x[3*MOD_WIDTH-1:2*MOD_WIDTH];
    assign x3  = x[WIDTH-1:3*MOD_WIDTH];
    assign y0  = y[MOD_WIDTH-1:0];
    assign y1  = y[2*MOD_WIDTH-1:MOD_WIDTH];
    assign y2  = y[3*MOD_WIDTH-1:2*MOD_WIDTH];
    assign y3  = y[WIDTH-1:3*MOD_WIDTH];

    carry_propagate_adder #(.WIDTH(MOD_WIDTH)) uuu_inst_low(
        .x(x0),
        .y(y0),
        .c_in(cin),
        .sum(sum0),
        .c_out(cout0)
    );


    carry_propagate_adder #(.WIDTH(MOD_WIDTH)) uuu_inst_middle_0(
        .x(x1),
        .y(y1),
        .c_in(1'b0),
        .sum(sum1_0),
        .c_out(cout1_0)
    );
    carry_propagate_adder #(.WIDTH(MOD_WIDTH)) uuu_inst_middle_1(
        .x(x1),
        .y(y1),
        .c_in(1'b1),
        .sum(sum1_1),
        .c_out(cout1_1)
    );
    assign sum1 = cout0 ? sum1_1 : sum1_0;
    assign cout1 = cout0 ? cout1_1 : cout1_0;


    carry_propagate_adder #(.WIDTH(MOD_WIDTH)) uuu_inst_high_low_0(
        .x(x2),
        .y(y2),
        .c_in(1'b0),
        .sum(sum2_0),
        .c_out(cout2_0)
    );
    carry_propagate_adder #(.WIDTH(MOD_WIDTH)) uuu_inst_high_low_1(
        .x(x2),
        .y(y2),
        .c_in(1'b1),
        .sum(sum2_1),
        .c_out(cout2_1)
    );
    carry_propagate_adder #(.WIDTH(MOD_WIDTH)) uuu_inst_high_high_0(
        .x(x3),
        .y(y3),
        .c_in(1'b0),
        .sum(sum3_0),
        .c_out(cout3_0)
    );
    carry_propagate_adder #(.WIDTH(MOD_WIDTH)) uuu_inst_high_high_1(
        .x(x3),
        .y(y3),
        .c_in(1'b1),
        .sum(sum3_1),
        .c_out(cout3_1)
    );

    assign sum3_real0 = cout2_0 ? sum3_1 : sum3_0;
    assign sum3_real1 = cout2_1 ? sum3_1 : sum3_0;
    assign sum_high   = cout1   ? {sum3_real1,sum2_1} : {sum3_real0,sum2_0};

    assign cout3_real0 = cout2_0 ? cout3_1 : cout3_0;
    assign cout3_real1 = cout2_1 ? cout3_1 : cout3_0;
    
    assign cout = cout1 ? cout3_real1 : cout3_real0;
    assign sum = {sum_high,sum1,sum0};
endmodule