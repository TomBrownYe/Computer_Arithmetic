//本架构为10-4计数器，参见Fig8.16
`include"FA.v"
`include"HA.v"

module counter_10_4(
    input [9:0] data_in,
    output [3:0] sum_out
);
    wire [6:0] level1_sum;
    wire [4:0] level2_sum;
    wire [4:0] level3_sum;
    wire [3:0] level4_sum;
    wire [3:0] level5_sum;

    //level1
    assign level1_sum[0] = data_in[0];
    FA fa1_1(
        .a(data_in[1]),
        .b(data_in[2]),
        .cin(data_in[3]),
        .sum(level1_sum[1]),
        .cout(level1_sum[4])
    );
    FA fa1_2(
        .a(data_in[4]),
        .b(data_in[5]),
        .cin(data_in[6]),
        .sum(level1_sum[2]),
        .cout(level1_sum[5])
    );
    FA fa1_3(
        .a(data_in[7]),
        .b(data_in[8]),
        .cin(data_in[9]),
        .sum(level1_sum[3]),
        .cout(level1_sum[6])
    );

    //level2
    assign level2_sum[0] = level1_sum[0];
    FA fa2_1(
        .a(level1_sum[1]),
        .b(level1_sum[2]),
        .cin(level1_sum[3]),
        .sum(level2_sum[1]),
        .cout(level2_sum[2])
    );
    FA fa2_2(
        .a(level1_sum[4]),
        .b(level1_sum[5]),
        .cin(level1_sum[6]),
        .sum(level2_sum[3]),
        .cout(level2_sum[4])
    );

    //level3
    HA ha3_1(
        .a(level2_sum[0]),
        .b(level2_sum[1]),
        .sum(level3_sum[0]),
        .cout(level3_sum[1])
    );
    assign level3_sum[2] = level2_sum[2];
    assign level3_sum[3] = level2_sum[3];
    assign level3_sum[4] = level2_sum[4];

    //level4
    FA fa4_1(
        .a(level3_sum[1]),
        .b(level3_sum[2]),
        .cin(level3_sum[3]),
        .sum(level4_sum[1]),
        .cout(level4_sum[2])
    );
    assign level4_sum[0] = level3_sum[0];
    assign level4_sum[3] = level3_sum[4];

    //level5
    HA ha5_1(
        .a(level4_sum[2]),
        .b(level4_sum[3]),
        .sum(level5_sum[2]),
        .cout(level5_sum[3])
    );
    assign level5_sum[0] = level4_sum[0];
    assign level5_sum[1] = level4_sum[1];
    
    //final result
    assign sum_out = level5_sum;
endmodule
