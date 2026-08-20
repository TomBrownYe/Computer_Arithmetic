//本架构为Ladner-Fischer parallel prefix tree,即LF加法树，参见Fig6.7
`include "cent.v"
module LF_prefix_tree #(
    parameter WIDTH = 32
)(
    input  [WIDTH-1:0] g_in,  // 预处理后的产生信号
    input  [WIDTH-1:0] p_in,  // 预处理后的传递信号
    output [WIDTH-1:0] G_out, // 算出的全局产生信号 (即真正的进位)
    output [WIDTH-1:0] P_out  // 算出的全局传递信号
);
    
    localparam STAGE = $clog2(WIDTH);
    
    wire [WIDTH-1:0] g_tree [0:STAGE];
    wire [WIDTH-1:0] p_tree [0:STAGE];

    assign g_tree[0] = g_in;
    assign p_tree[0] = p_in;

    genvar level, idx;
    generate
    // 1. 正常的级数遍历 (1 到 STAGE)
    for (level = 1; level <= STAGE; level = level + 1) begin: gen_stage
        localparam BLOCK = 2 ** level;
        localparam HALF_BLOCK = 2 ** (level - 1);

        // 2. 上帝视角：直接遍历所有的节点 0 到 WIDTH-1
        for (idx = 0; idx < WIDTH; idx = idx + 1) begin: gen_node
            
            // 节点自我定位：我在哪个块？我的广播源是谁？我是不是 Target？
            localparam BASE = (idx / BLOCK) * BLOCK;       // 当前节点所在块的起点
            //注：Verilog中参数的除法是向下取整的，与C/C++同理

            localparam SOURCE = BASE + HALF_BLOCK - 1;      // 当前块的广播源
            localparam IS_TARGET = ((idx % BLOCK) >= HALF_BLOCK); // 如果在块的后半段，我就是Target

            // 3. 终极逻辑判断
            if (IS_TARGET && (SOURCE < WIDTH)) begin
                // 我是合法的 Target，且我的广播源真实存在！进行 cent 运算！
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
                // 其他所有情况：
                // 1. 我在块的右半边，不接收广播
                // 2. 我是幽灵 Target (其实进不来这里因为 idx < WIDTH)
                // 3. 我的 SOURCE 是个幽灵
                // 统统直接旁路，继承上一层的数据！(完美解决高阻态和越界问题)
                assign g_tree[level][idx] = g_tree[level-1][idx];
                assign p_tree[level][idx] = p_tree[level-1][idx];
            end
        end
    end
    endgenerate

    assign G_out = g_tree[STAGE];
    assign P_out = p_tree[STAGE];

endmodule