//本架构为Brent-Kung parallel prefix tree,即BK加法树，参见Fig6.8
`include "cent_in_7.v"
module BK_prefix_tree #(
    parameter WIDTH = 32
)(
    input  [WIDTH-1:0] g_in,  // 预处理后的产生信号
    input  [WIDTH-1:0] p_in,  // 预处理后的传递信号
    output [WIDTH-1:0] G_out, // 算出的全局产生信号 (即真正的进位)
    output [WIDTH-1:0] P_out  // 算出的全局传递信号
);

    localparam STAGE = $clog2(WIDTH);
    
    wire [WIDTH-1:0] g_tree [0:2*STAGE-1];
    wire [WIDTH-1:0] p_tree [0:2*STAGE-1];
    
    assign g_tree[0] = g_in;
    assign p_tree[0] = p_in;

    // STAGE1:正向树, level从1遍历到STAGE
    genvar level_pos, idx_pos;
    generate 
        for(level_pos = 1 ; level_pos <= STAGE ; level_pos = level_pos + 1)begin:forward_tree
           
            localparam BLOCK = 2 ** (level_pos);
            localparam HALF_BLOCK = 2 ** (level_pos - 1);

            for(idx_pos = 0; idx_pos < WIDTH ; idx_pos = idx_pos + 1)begin:forward_node

                localparam IS_TARGET =((idx_pos + 1) % BLOCK == 0);//判断该位置是否是接收端
                localparam SOURCE = idx_pos - HALF_BLOCK;//SOURCE需要大于0以防止幽灵发射端
                if(IS_TARGET && (SOURCE >= 0))begin
                cent u_pos (
                    .g_right (g_tree[level_pos-1][SOURCE]),
                    .g_left  (g_tree[level_pos-1][idx_pos]),
                    .p_right (p_tree[level_pos-1][SOURCE]),
                    .p_left  (p_tree[level_pos-1][idx_pos]),
                    .G_out   (g_tree[level_pos][idx_pos]),
                    .P_out   (p_tree[level_pos][idx_pos])
                );
                end
                else begin
                assign g_tree[level_pos][idx_pos] = g_tree[level_pos-1][idx_pos];
                assign p_tree[level_pos][idx_pos] = p_tree[level_pos-1][idx_pos];
                end
            end
        end
    endgenerate

    // STAGE2:反向树，level从STAGE+1到2*STAGE-2，但步长会递减，注意与正向树有所重叠
    genvar level_neg, idx_neg;
    generate
        //我们以Fig6.9举例：书中说的树是有6层，是因为level4这一层同时执行了正向树的最后一步和反向树的第一步。
        //它们在时间上是并行的。
        //但在写二维数组时，强行把正向和反向挤在同一个 level 里会导致代码极度复杂且容易产生多重驱动。
        //所以我们在代码里把它们“铺开”：正向跑 STAGE 步，反向跑 STAGE - 1 步。
        //总层数从而为STAGE + (STAGE - 1) = 2*STAGE - 1。
        for(level_neg = STAGE + 1; level_neg <=  2*STAGE - 1 ; level_neg = level_neg + 1)begin:inverse_tree
           
            localparam LEVEL_INV = 2*STAGE - level_neg;
            localparam BLOCK = 2 ** LEVEL_INV;
            localparam HALF_BLOCK = 2 ** (LEVEL_INV - 1);

            for(idx_neg = 0; idx_neg < WIDTH ; idx_neg = idx_neg + 1)begin:inverse_node

                localparam IS_TARGET =((idx_neg + 1 - HALF_BLOCK) % BLOCK == 0);
                localparam SOURCE = idx_neg - HALF_BLOCK;
                if(IS_TARGET && (SOURCE >= 0))begin
                cent u_pos (
                    .g_right (g_tree[level_neg-1][SOURCE]),
                    .g_left  (g_tree[level_neg-1][idx_neg]),
                    .p_right (p_tree[level_neg-1][SOURCE]),
                    .p_left  (p_tree[level_neg-1][idx_neg]),
                    .G_out   (g_tree[level_neg][idx_neg]),
                    .P_out   (p_tree[level_neg][idx_neg])
                );
                end
                else begin
                assign g_tree[level_neg][idx_neg] = g_tree[level_neg-1][idx_neg];
                assign p_tree[level_neg][idx_neg] = p_tree[level_neg-1][idx_neg];
                end
            end
        end
    endgenerate

    assign G_out = g_tree [2*STAGE - 1];
    assign P_out = p_tree [2*STAGE - 1];

endmodule
