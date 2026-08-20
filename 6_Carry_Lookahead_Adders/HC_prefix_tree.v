//本架构为Han-Carlson prefix tree,即HC加法树，参见Fig6.11
`include "cent.v"
module HC_prefix_tree #(
    parameter WIDTH = 32
)(
    input  [WIDTH-1:0] g_in,  // 预处理后的产生信号
    input  [WIDTH-1:0] p_in,  // 预处理后的传递信号
    output [WIDTH-1:0] G_out, // 算出的全局产生信号 (即真正的进位)
    output [WIDTH-1:0] P_out  // 算出的全局传递信号
);
    localparam STAGE = $clog2(WIDTH);
    
    wire [WIDTH-1:0] g_tree [0:STAGE+1];
    wire [WIDTH-1:0] p_tree [0:STAGE+1];
    
    assign g_tree[0] = g_in;
    assign p_tree[0] = p_in;

    genvar level, idx;
    generate
        for(level = 1; level <= STAGE + 1; level = level + 1)begin:gen_stage
            
            localparam HALF_BLOCK = 2 ** (level - 1);
            
            // Stage 1： 顶层BK核心
            //动作：把相邻2个数据成对合并
            //选拔target：提取出所有奇数号线
            //寻找source：在target旁边小于其的那根偶数号线
            //结果：所有偶数线旁路，所有奇数线变成了 2 位的局部前缀和。
            if(level == 1)begin

                for(idx = 0; idx < WIDTH; idx = idx + 1)begin:gen_node

                    localparam IS_TARGET = (idx % 2 == 1);
                    localparam SOURCE = idx - 1;

                    if(IS_TARGET)begin
                        cent u_cent (
                        .g_right (g_tree[level-1][SOURCE]),
                        .g_left  (g_tree[level-1][idx]),
                        .p_right (p_tree[level-1][SOURCE]),
                        .p_left  (p_tree[level-1][idx]),
                        .G_out   (g_tree[level][idx]),
                        .P_out   (p_tree[level][idx])
                        );
                    end
                    else begin
                        assign g_tree[level][idx] = g_tree[level-1][idx];
                        assign p_tree[level][idx] = p_tree[level-1][idx];
                    end
                end
            end

            // Stage 3： 底层BK核心
            //动作：把算好的奇数线结果，补发给右边相邻的偶数线。
            //选拔target：这次轮到偶数号线了！（而且第 0 位不需要算，它本来就是绝对进位）
            //寻找source：在target旁边小于其的那根奇数号线
            //结果：所有偶数线拿到进位，整个系统全员计算完毕。
            else if (level == STAGE + 1)begin
                for(idx = 0; idx < WIDTH; idx = idx + 1)begin:gen_node

                    localparam IS_TARGET = (idx % 2 == 0) && (idx > 0);
                    localparam SOURCE = idx - 1;

                    if(IS_TARGET)begin
                        cent u_cent (
                        .g_right (g_tree[level-1][SOURCE]),
                        .g_left  (g_tree[level-1][idx]),
                        .p_right (p_tree[level-1][SOURCE]),
                        .p_left  (p_tree[level-1][idx]),
                        .G_out   (g_tree[level][idx]),
                        .P_out   (p_tree[level][idx])
                        );
                    end
                    else begin
                        assign g_tree[level][idx] = g_tree[level-1][idx];
                        assign p_tree[level][idx] = p_tree[level-1][idx];
                    end
                end
            end

            // Stage 2： 中层KS核心
            //动作：仅仅在奇数线上，跑完整的 Kogge-Stone 算法。
            //核心步长：你的步长必须跟着层数呈指数级增长
            //(注意：当 level=2 时，步长是 2；level=3 时，步长是 4。
            //这完美跨过了那些闲置的偶数线！)
            //选拔target：必须同时满足是奇数线，且左边有足够的步长。
            //寻找source：在target旁边小于其一个步长的那根奇数号线（其同时也是旁边的旁边的target）
            //结果：这一段循环跑完，所有的奇数线全部变成了全局前缀和！偶数线依然全程旁路休眠。
            else begin
                for(idx = 0; idx < WIDTH; idx = idx + 1)begin:gen_node

                    localparam IS_TARGET = (idx % 2 ==1) && (idx >= HALF_BLOCK);
                    localparam SOURCE = idx - HALF_BLOCK;

                    if(IS_TARGET)begin
                        cent u_cent (
                        .g_right (g_tree[level-1][SOURCE]),
                        .g_left  (g_tree[level-1][idx]),
                        .p_right (p_tree[level-1][SOURCE]),
                        .p_left  (p_tree[level-1][idx]),
                        .G_out   (g_tree[level][idx]),
                        .P_out   (p_tree[level][idx])
                        );
                    end
                    else begin
                        assign g_tree[level][idx] = g_tree[level-1][idx];
                        assign p_tree[level][idx] = p_tree[level-1][idx];
                    end
                end
            end
        end
    endgenerate

        assign G_out = g_tree[STAGE + 1];
        assign P_out = p_tree[STAGE + 1];

endmodule