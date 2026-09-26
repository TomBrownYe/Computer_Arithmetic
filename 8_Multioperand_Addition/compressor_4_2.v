//本模块为4-2压缩器
`include"carry_save_adder_in_8.v"

module compressor_4_2#(
    parameter WIDTH = 32
)(
    input [WIDTH-1:0] data_in0,
    input [WIDTH-1:0] data_in1,
    input  [WIDTH-1:0] data_in2,
    input  [WIDTH-1:0] data_in3,

    output [WIDTH+1:0] sum
);
    //内部产生的横向输出
    wire [WIDTH-1:0] psi_out;

    //接入切片的内部横向输入
    wire [WIDTH-1:0] psi_in = {psi_out[WIDTH-2:0],1'b0};

    wire [WIDTH-1:0] level1_sum;

    //level1
    carry_save_adder #(.WIDTH(WIDTH)) csa1_1(
        .x(data_in0),
        .y(data_in1),
        .z(data_in2),
        .sum(level1_sum),
        .carry(psi_out)
    );

    //level2
    //产生的sum_tmp和carry_tmp需要经过边缘溢出信号回收才能得到最终sum
    wire [WIDTH-1:0] sum_tmp;
    wire [WIDTH-1:0] carry_tmp;

    carry_save_adder #(.WIDTH(WIDTH)) csa2_1(
        .x(level1_sum),
        .y(data_in3),
        .z(psi_in),
        .sum(sum_tmp),
        .carry(carry_tmp)
    );

    //边缘溢出信号回收
    //权重为2^WIDTH的位有：carry_tmp[WIDTH-1]、psi1_out[WIDTH-1]
    
    //最终的sum输出(这里可接入CPA来求得最终结果)
    assign sum = {1'b0, psi_out[WIDTH-1], sum_tmp} + {1'b0 ,carry_tmp, 1'b0};

endmodule

