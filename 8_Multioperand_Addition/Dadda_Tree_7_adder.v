//本架构参见Fig8.14与Fig8.15和Table8.1，具体接口连线选择了更节省硬件面积的Fig8.15
`include "carry_save_adder_in_8.v"
`include "carry_propagate_adder_in_8.v"
`include "HA.v"
`include "FA.v"

module Dadda_Tree_7_adder #(
    // 该固定的7操作数Dadda Tree使用了低至k-3的切片。
    // 因此每个输入数据位宽k至少为4
    parameter integer k = 32
) (
    input [k-1:0] data_in0,
    input [k-1:0] data_in1,
    input [k-1:0] data_in2,
    input [k-1:0] data_in3,
    input [k-1:0] data_in4,
    input [k-1:0] data_in5,
    input [k-1:0] data_in6,
    output [k+2:0] sum
);
    wire [k-1:0] data_in [0:6];
    assign data_in[0] = data_in0;
    assign data_in[1] = data_in1;
    assign data_in[2] = data_in2;
    assign data_in[3] = data_in3;
    assign data_in[4] = data_in4;
    assign data_in[5] = data_in5;
    assign data_in[6] = data_in6;

    wire [k:0] level1_sum [0:5];
    wire [k:0] level2_sum [0:3];
    wire [k+1:0] level3_sum [0:2];
    wire [k+1:0] level4_sum [0:1];
    wire         level4_tmp;

    //level1
    carry_save_adder #(.WIDTH(k)) csa1_1(
        .x(data_in[0]),//[0,k-1]
        .y(data_in[1]),//[0,k-1]
        .z(data_in[2]),//[0,k-1]
        .sum(level1_sum[0][k-1:0]),//[0,k-1]
        .carry(level1_sum[1][k:1])//[1,k]
    );
    assign level1_sum[2] = {1'b0, data_in[3]};//[0,k-1]
    assign level1_sum[3] = {1'b0, data_in[4]};//[0,k-1]
    assign level1_sum[4] = {1'b0, data_in[5]};//[0,k-1]
    assign level1_sum[5] = {1'b0, data_in[6]};//[0,k-1]

    //level2
    assign level1_sum[0][k] = 1'b0;
    assign level1_sum[1][0] = 1'b0;

    carry_save_adder #(.WIDTH(k-1)) csa2_1(
        .x(level1_sum[0][k-1:1]),//[1,k-1]
        .y(level1_sum[1][k-1:1]),//[1,k-1]
        .z(level1_sum[2][k-1:1]),//[1,k-1]
        .sum(level2_sum[0][k-1:1]),//[1,k-1]
        .carry(level2_sum[1][k:2])//[2,k]
    );
    carry_save_adder #(.WIDTH(k)) csa2_2(
        .x(level1_sum[3][k-1:0]),//[0,k-1]
        .y(level1_sum[4][k-1:0]),//[0,k-1]
        .z(level1_sum[5][k-1:0]),//[0,k-1]
        .sum(level2_sum[2][k-1:0]),//[0,k-1]
        .carry(level2_sum[3][k:1])//[1,k]
    );

    //level3
    assign level2_sum[0][0] = level1_sum[0][0];//[0]
    assign level2_sum[0][k] = level1_sum[1][k];//[k]
    assign level2_sum[1][0] = level1_sum[2][0];//[0]
    assign level2_sum[3][0] = 1'b0;
    assign level2_sum[1][1] = 1'b0;
    assign level2_sum[2][k] = 1'b0;

    carry_save_adder #(.WIDTH(1)) csa3_1(
        .x(level2_sum[0][0]),//[0]
        .y(level2_sum[1][0]),//[0]
        .z(level2_sum[2][0]),//[0]
        .sum(level3_sum[0][0]),//[0]
        .carry(level3_sum[1][1])//[1]
    );
    HA ha3_1(
        .a(level2_sum[0][1]),//[1]
        .b(level2_sum[2][1]),//[1]
        .sum(level3_sum[0][1]),//[1]
        .cout(level3_sum[1][2])//[2]
    );
    carry_save_adder #(.WIDTH(k-2)) csa3_2(
        .x(level2_sum[0][k-1:2]),//[2,k-1]
        .y(level2_sum[1][k-1:2]),//[2,k-1]
        .z(level2_sum[2][k-1:2]),//[2,k-1]
        .sum(level3_sum[0][k-1:2]),//[2,k-1]
        .carry(level3_sum[1][k:3])//[3,k]
    );
    carry_save_adder #(.WIDTH(1)) csa3_3(
        .x(level2_sum[0][k]),//[k]
        .y(level2_sum[1][k]),//[k]
        .z(level2_sum[3][k]),//[k]
        .sum(level3_sum[0][k]),//[k]
        .carry(level3_sum[1][k+1])//[k+1]
    );

    //level4
    assign level3_sum[0][k+1] = 1'b0;
    assign level3_sum[1][0] = 1'b0;
    assign level3_sum[2][0] = 1'b0;
    assign level3_sum[2][k-1:1] = level2_sum[3][k-1:1];
    assign level3_sum[2][k+1:k] = 2'b0;

    assign level4_sum[0][0] = level3_sum[0][0];//[0]
    assign level4_sum[0][1] = level3_sum[0][1];//[1]
    assign level4_sum[1][1] = level3_sum[1][1];//[1]
    assign level4_tmp       = level3_sum[2][1];//[1]
    assign level4_sum[1][2] = level3_sum[2][2];//[2]

    HA ha4_1(
        .a(level3_sum[0][2]),//[2]
        .b(level3_sum[1][2]),//[2]
        .sum(level4_sum[0][2]),//[2]
        .cout(level4_sum[1][3])//[3]
    );
    carry_save_adder #(.WIDTH(k-3)) csa4_1(
        .x(level3_sum[0][k-1:3]),//[3,k-1]
        .y(level3_sum[1][k-1:3]),//[3,k-1]
        .z(level3_sum[2][k-1:3]),//[3,k-1]
        .sum(level4_sum[0][k-1:3]),//[3,k-1]
        .carry(level4_sum[1][k:4])//[4,k]
    );
    HA ha4_2(
        .a(level3_sum[0][k]),//[k]
        .b(level3_sum[1][k]),//[k]
        .sum(level4_sum[0][k]),//[k]
        .cout(level4_sum[1][k+1])//[k+1]
    );
    assign level4_sum[0][k+1] = level3_sum[1][k+1];//[k+1]

    //CPA
    assign sum[0] = level4_sum[0][0];//[0]
    carry_propagate_adder #(.WIDTH(k+1)) cpa(
        .x(level4_sum[0][k+1:1]),//[1,k+1]
        .y(level4_sum[1][k+1:1]),//[1,k+1]
        .c_in(level4_tmp),//[1]
        .sum(sum[k+1:1]),//[1,k+1]
        .c_out(sum[k+2])//[k+2]
    );

endmodule
