//本架构基于Fig7.2，其各个模块的位宽是从左到右从b递增到b+0.5t-1再从b+0.5t-1递减到b
`include "sub_carry_skip_adder.v"

module symmetry_carry_skip_adder #(
    parameter B = 8,
    parameter T = 4, //T必须是偶数
    parameter WIDTH =T * B + ((T * (T - 2)) / 4)
) (
    input [WIDTH - 1:0] x,
    input [WIDTH - 1:0] y,
    input               cin,
    output [WIDTH - 1:0] sum,
    output               cout
);
    localparam HALF_WIDTH = WIDTH / 2;
    localparam STAGE = T / 2;

    wire [HALF_WIDTH - 1:0] x1, y1, x2, y2;
    wire [HALF_WIDTH - 1:0] sum1, sum2;
    wire [STAGE - 1:0] carry1, carry2;
    
    assign x1 = x[HALF_WIDTH - 1:0];
    assign y1 = y[HALF_WIDTH - 1:0];
    assign x2 = x[WIDTH - 1:HALF_WIDTH];
    assign y2 = y[WIDTH - 1:HALF_WIDTH];

    // STAGE 1 : 位宽递增的模块生成（每个模块从低位到高位的位宽从b递增到b+0.5t-1）
    genvar i;
    generate
        for(i = 0; i < STAGE; i = i + 1)begin:gen_low_module
            // 我们需要算出第i个模块的索引
            // 第0个模块位宽（首项）：W_0 = B
            // 第i-1个模块的位宽（末项）：W_(i-1) = B + i - 1
            // 第i个模块的位宽（通项）：W_i =  B + i
            //第i个模块的位宽的起始索引为第0个模块的位宽一路加到第i-1个模块的位宽之和(共i项)
            //S_i = W_0 + W_1 + ... + W_(i-1) = [B + (B + i - 1)] * i / 2 = (2B + i - 1) * i / 2
            localparam CUR_WIDTH = B + i;
            localparam START_IDX = ((2 * B + i - 1) * i) / 2;
            
            if(i == 0)begin
                sub_carry_skip_adder #(
                .WIDTH(CUR_WIDTH)
                ) sub_carry_skip_adder_inst(
                    .x(x1[START_IDX +: CUR_WIDTH]),
                    .y(y1[START_IDX +: CUR_WIDTH]),
                    .c_in(cin),
                    .sum(sum1[START_IDX +: CUR_WIDTH]),
                    .c_out(carry1[i])
                );
            end
            else begin
                sub_carry_skip_adder #(
                .WIDTH(CUR_WIDTH)
                ) sub_carry_skip_adder_inst(
                    .x(x1[START_IDX +: CUR_WIDTH]),
                    .y(y1[START_IDX +: CUR_WIDTH]),
                    .c_in(carry1[i - 1]),
                    .sum(sum1[START_IDX +: CUR_WIDTH]),
                    .c_out(carry1[i])
                );
            end
        end
    endgenerate

    // STAGE 2 : 位宽递减的模块生成（每个模块从低位到高位的位宽从b+0.5t-1递减到b）
    genvar j;
    generate
        for(j = 0; j < STAGE; j = j + 1)begin:gen_high_module
            // 我们需要算出第j个模块的索引
            // 第0个模块位宽（首项）：W_0 = B + STAGE - 1
            // 第j-1个模块的位宽（末项）：W_(j-1) = B + STAGE - j
            // 第j个模块的位宽（通项）：W_j =  B + STAGE - 1 - j
            //第j个模块的位宽的起始索引为第0个模块的位宽一路加到第j-1个模块的位宽之和(共j项)
            //S_i = W_0 + W_1 + ... + W_(j-1) = 
            //[(B + STAGE - 1) + (B + STAGE - j)] * j / 2 = (2B + 2STAGE - 1 - j) * j / 2
            localparam CUR_WIDTH = B + STAGE - 1 - j;
            localparam START_IDX = ((2 * B + 2 * STAGE - j - 1) * j) / 2;
            
             if(j == 0) begin
                sub_carry_skip_adder #(
                .WIDTH(CUR_WIDTH)
                ) sub_carry_skip_adder_inst(
                    .x(x2[START_IDX +: CUR_WIDTH]),
                    .y(y2[START_IDX +: CUR_WIDTH]),
                    .c_in(carry1[STAGE - 1]),
                    .sum(sum2[START_IDX +: CUR_WIDTH]),
                    .c_out(carry2[j])
                );
            end

            else begin
                sub_carry_skip_adder #(
                .WIDTH(CUR_WIDTH)
                ) sub_carry_skip_adder_inst(
                    .x(x2[START_IDX +: CUR_WIDTH]),
                    .y(y2[START_IDX +: CUR_WIDTH]),
                    .c_in(carry2[j - 1]),
                    .sum(sum2[START_IDX +: CUR_WIDTH]),
                    .c_out(carry2[j])
                );
            end
        end
    endgenerate

    assign sum = {sum2, sum1};
    assign cout = carry2[STAGE - 1];

endmodule