//本模块为7-2压缩器，取自教材内的正文所提留下的练习，设计架构请参照图片
`include "carry_save_adder_in_8.v"

module compressor_7_2 #(
    parameter WIDTH = 8
)(
    input [WIDTH-1:0] data_in0,
    input [WIDTH-1:0] data_in1,
    input [WIDTH-1:0] data_in2,
    input [WIDTH-1:0] data_in3,
    input [WIDTH-1:0] data_in4,
    input [WIDTH-1:0] data_in5,
    input [WIDTH-1:0] data_in6,

    output [WIDTH+2:0] sum
);
    wire [WIDTH-1:0] level1_sum [0:4];
    wire [WIDTH-1:0] level2_sum [0:3];

    //level1
    assign level1_sum[0] = data_in0;

    carry_save_adder #(
        .WIDTH(WIDTH)
    ) csa1_1 (
        .x(data_in1),
        .y(data_in2),
        .z(data_in3),
        .sum(level1_sum[1]),
        .carry(level1_sum[2])
    );
    carry_save_adder #(
        .WIDTH(WIDTH)
    ) csa1_2 (
        .x(data_in4),
        .y(data_in5),
        .z(data_in6),
        .sum(level1_sum[3]),
        .carry(level1_sum[4])
    );

    //level2
    carry_save_adder #(
        .WIDTH(WIDTH)
    ) csa2_1 (
        .x(level1_sum[0]),
        .y(level1_sum[1]),
        .z(level1_sum[3]),
        .sum(level2_sum[0]),
        .carry(level2_sum[1])
    );

    assign level2_sum[2] = level1_sum[2];
    assign level2_sum[3] = level1_sum[4];

    //level3
    // 内部产生的横向输出
    wire [WIDTH-1:0] psi1_out; //传到比本权重高2的切片
    wire [WIDTH-1:0] psi2_out; //传到比本权重高4的切片

    // 送给自己的横向输入（核心：整体移位错位对齐！）
    wire [WIDTH-1:0] psi1_in = {psi1_out[WIDTH-2:0], 1'b0};   // 权重 +1，向左平移 1 位
    wire [WIDTH-1:0] psi2_in = {psi2_out[WIDTH-3:0], 2'b00};  // 权重 +2，向左平移 2 位

    //产生的sum_tmp和carry_tmp需要经过边缘溢出信号回收才能得到最终sum
    wire [WIDTH-1:0] sum_tmp;
    wire [WIDTH-1:0] carry_tmp;

    carry_save_adder #(
        .WIDTH(WIDTH)
    ) csa3_1 (
        .x(level2_sum[0]),
        .y(psi1_in),
        .z(psi2_in),
        .sum(sum_tmp),
        .carry(carry_tmp)
    );
    carry_save_adder #(
        .WIDTH(WIDTH)
    ) csa3_2 (
        .x(level2_sum[1]),
        .y(level2_sum[2]),
        .z(level2_sum[3]),
        .sum(psi1_out),
        .carry(psi2_out)
    );

    //level4：边缘溢出信号回收
    
    //先处理溢出信号
    //权重为2^WIDTH的位有：carry_tmp[WIDTH-1]、psi1_out[WIDTH-1]、psi2_out[WIDTH-2]
    //权重为2^(WIDTH+1)的位有：psi2_out[WIDTH-1]
    //注意到权重为2^WIDTH的位有三个数，我们可以再通过一次CSA压缩
    wire sum_W0, sum_W1;
    carry_save_adder #(.WIDTH(1)) csa4_1(
        .x(carry_tmp[WIDTH-1]),
        .y(psi1_out[WIDTH-1]),
        .z(psi2_out[WIDTH-2]),
        .sum(sum_W0),
        .carry(sum_W1)
    );

    //最终的sum输出(这里可接入CPA来求得最终结果)
    assign sum = {sum_W1, sum_W0, sum_tmp} + {psi2_out[WIDTH-1], 1'b0, carry_tmp[WIDTH-2:0], 1'b0};

endmodule