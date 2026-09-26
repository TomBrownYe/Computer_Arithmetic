//本架构参见Fig8.9,Fig8.10，Fig8.11，Fig8.12，具体接口连线为Fig8.12
`include"carry_save_adder_in_8.v"
`include"carry_propagate_adder_in_8.v"

module Wallace_Tree_7_adder #(
    parameter k = 32
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

    wire [k-1:0] level1_sum [0:4];
    wire [k-1:0] level2_sum [0:3];
    wire [k-1:0] level3_sum [0:2];
    wire [k:0] level4_sum [0:1];

    //第一层CSA

        //data_in[0]直接输入到level1_sum[0]
        assign level1_sum[0] = data_in[0];//[0,k-1]

        //剩下六个加数三个分一组，各自通过一个CSA
        carry_save_adder #(.WIDTH(k)) csa1_1 (
            .x(data_in[1]),//[0,k-1]
            .y(data_in[2]),//[0,k-1]
            .z(data_in[3]),//[0,k-1]
            .sum(level1_sum[1]),//[0,k-1]
            .carry(level1_sum[2])//[1,k]
        );

        carry_save_adder #(.WIDTH(k)) csa1_2 (
            .x(data_in[4]),//[0,k-1]
            .y(data_in[5]),//[0,k-1]
            .z(data_in[6]),//[0,k-1]
            .sum(level1_sum[3]),//[0,k-1]
            .carry(level1_sum[4])//[1,k]
        );

    //第二层CSA

        //两个CSA的carry权重比sum高一位，因此根据架构图将其输向下一层CSA
        assign level2_sum[2] = level1_sum[2];//[1,k]
        assign level2_sum[3] = level1_sum[4];//[1,k]

        //剩下3个加数权重一致，分配一个CSA
        carry_save_adder #(.WIDTH(k)) csa2_1 (
            .x(level1_sum[0]),//[0,k-1]
            .y(level1_sum[1]),//[0,k-1]
            .z(level1_sum[3]),//[0,k-1]
            .sum(level2_sum[0]),//[0,k-1]
            .carry(level2_sum[1])//[1,k]
        );

    //第三层CSA
        
        //level2_sum[0]直接通往下一层，并且最低位即为sum[0]
        assign level3_sum[0] = level2_sum[0];//[0,k-1]

        //剩下三个加数权重一致，分配一个CSA
        carry_save_adder #(.WIDTH(k)) csa3_1 (
            .x(level2_sum[1]),//[1,k]
            .y(level2_sum[2]),//[1,k]
            .z(level2_sum[3]),//[1,k]
            .sum(level3_sum[1]),//[1,k]
            .carry(level3_sum[2])//[2,k+1]
        );

    //第四层CSA
     
        //level3_sum[0]的最低位为sum[0]，因为此时最低位只有一个数，无法再压缩相加
        assign sum[0] = level3_sum[0][0];

        //本层共3个加数，且权重最高的为level3_sum[2]，此时level3_sum[0]需要高位补2个0、level3_sum[1]需要补1个0以对齐方便通过CSA
        carry_save_adder #(.WIDTH(k+1)) csa4_1 (
            .x({2'b00,level3_sum[0][k-1:1]}),//[1,k-1]
            .y({1'b0,level3_sum[1]}),//[1,k]
            .z({level3_sum[2],1'b0}),//[2,k+1]
            .sum(level4_sum[0]),//[1,k+1]
            .carry(level4_sum[1])//[2,k+1],最高位第k+1位只有一个数，所以无需再向上进1位
        );
    
    //最后一层CPA
        
        //此时level4_sum[0]的最低位只有一个数，无法再压缩相加，直接输出
        assign sum[1] = level4_sum[0][0];

        //level4的两个加数权重一致，分配一个CPA作最终求和
        carry_propagate_adder #(.WIDTH(k)) cpa(
            .x(level4_sum[0][k:1]),//[2,k+1]
            .y(level4_sum[1][k-1:0]),//[2,k+1],level4_sum[1]最低位为0，因为最低位无进位，直接舍弃
            .c_in(1'b0),
            .sum(sum[k+1:2]),//[2,k+1]
            .c_out(sum[k+2])//[k+2]
        );

endmodule
