//本架构参见表7.2，为位宽一般化的条件求和加法器
`include"sub_conditional_sum_adder.v"

module conditional_sum_adder #(
    parameter WIDTH = 13 // 任意输入位宽（如 13）
)(
    input  wire [WIDTH - 1 : 0] x,
    input  wire [WIDTH - 1 : 0] y,
    input  wire                 cin,
    output wire [WIDTH - 1 : 0] sum,
    output wire                 cout
);

    
    // 1. 计算完美二叉树所需的物理参数
    
        // 树的总层数 (例如 WIDTH=13，STAGES=4)
    localparam STAGES = $clog2(WIDTH); 
    
        // 补齐后的完美物理位宽 (例如 STAGES=4, PAD_WIDTH=16)
        localparam PAD_WIDTH = 1 << STAGES; 


    // 2. 内部补齐线网声明 (将输入强制扩展到 PAD_WIDTH)
    
        wire [PAD_WIDTH - 1 : 0] padded_x;
        wire [PAD_WIDTH - 1 : 0] padded_y;

        // 高位补 0，低位直接相连
        assign padded_x = {{ (PAD_WIDTH - WIDTH){1'b0} }, x};
        assign padded_y = {{ (PAD_WIDTH - WIDTH){1'b0} }, y};

    // 3. 二维数组布线网络：维度定义为 [级数][当前级的位宽]
        // 假设进位为 0 的完整二叉树数据流
        wire [PAD_WIDTH-1:0] sum_0  [0:STAGES];
        wire [PAD_WIDTH-1:0] cout_0 [0:STAGES];
    
        // 假设进位为 1 的完整二叉树数据流
        wire [PAD_WIDTH-1:0] sum_1  [0:STAGES];
        wire [PAD_WIDTH-1:0] cout_1 [0:STAGES];

    // 4. 底层例化第0级条件求和加法器子模块
        genvar idx_0;
        generate
            for(idx_0 = 0; idx_0 < PAD_WIDTH; idx_0 = idx_0 + 1) begin: stage_0
                sub_conditional_sum_adder uuu0(
                    .x(padded_x[idx_0]),
                    .y(padded_y[idx_0]),
                    .ci(1'b0),
                    .co(cout_0[0][idx_0]),
                    .si(sum_0[0][idx_0])
                );
                sub_conditional_sum_adder uuu1(
                    .x(padded_x[idx_0]),
                    .y(padded_y[idx_0]),
                    .ci(1'b1),
                    .co(cout_1[0][idx_0]),
                    .si(sum_1[0][idx_0])
                );
            end
        endgenerate

    // 5. 树状迭代合并（第1级到第STAGES级）
        genvar level,idx;
        generate 
            for(level = 1; level <= STAGES; level = level + 1)begin: gen_level
                localparam BLOCK = 2 ** level;
                localparam HALF_BLOCK = 2 ** (level - 1);
                
                for(idx = 0; idx < PAD_WIDTH; idx = idx + 1)begin: gen_block
                    // 参数设置
                    localparam BLOCK_START = (idx / BLOCK) * BLOCK;//计算当前位所在模块的起始位置
                    localparam BLOCK_END = BLOCK_START + BLOCK - 1;//计算当前位所在模块的结束位置
                    localparam HIGH_HALF_BLOCK_START = BLOCK_START + HALF_BLOCK;//计算当前位所在模块的高半部分起始位置
                    localparam LOW_HALF_BLOCK_END = BLOCK_START + HALF_BLOCK - 1;//计算当前位所在模块的低半部分结束位置
                    localparam IS_HIGH_HALF = (idx >= HIGH_HALF_BLOCK_START) && (idx <= BLOCK_END);//判断当前位是否在高半部分
                    
                    if(IS_HIGH_HALF)begin
                    assign sum_0[level][idx] = cout_0[level - 1][LOW_HALF_BLOCK_END]
                                             ? sum_1[level - 1][idx]
                                             : sum_0[level - 1][idx];
                    assign sum_1[level][idx] = cout_1[level - 1][LOW_HALF_BLOCK_END]
                                             ? sum_1[level - 1][idx]
                                             : sum_0[level - 1][idx];
                    assign cout_0[level][idx] = cout_0[level - 1][LOW_HALF_BLOCK_END]
                                              ? cout_1[level - 1][idx]
                                              : cout_0[level - 1][idx];
                    assign cout_1[level][idx] = cout_1[level - 1][LOW_HALF_BLOCK_END]
                                              ? cout_1[level - 1][idx]
                                              : cout_0[level - 1][idx];
                    end
                    else begin
                    assign sum_0[level][idx] = sum_0[level - 1][idx];
                    assign sum_1[level][idx] = sum_1[level - 1][idx];
                    assign cout_0[level][idx] = cout_0[level - 1][idx];
                    assign cout_1[level][idx] = cout_1[level - 1][idx];
                    end
                end
            end
        endgenerate

    // 6. 输出结果
        assign sum = cin ? sum_1[STAGES][WIDTH - 1:0] : sum_0[STAGES][WIDTH - 1:0];
        assign cout = cin ? cout_1[STAGES][WIDTH - 1] : cout_0[STAGES][WIDTH - 1];

endmodule
