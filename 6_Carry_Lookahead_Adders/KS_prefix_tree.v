//本架构为Kogge-Stone parallel prefix tree,即KS加法树，参见Fig6.10
`include "cent.v"
module KS_prefix_tree #(
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

    //KS加法树比较规整，所以不会像其它加法树那样在边界情况十分复杂
    genvar level,idx;
    generate
        for(level = 1; level <= STAGE; level = level + 1)begin:gen_stage
            
            localparam BLOCK = 2 ** level;//KS 树根本没有“分块（Block）”的概念！ 
            //每个人都是平等的个体，只要左边有对应步长的数据，拿过来算就完事了
            //所以24行代码可注释
            localparam HALF_BLOCK = 2 ** (level - 1);
            
            for(idx = 0; idx < WIDTH;idx = idx + 1)begin:gen_node
                
                    localparam SOURCE = idx - HALF_BLOCK;
                    localparam IS_TARGET = (idx >= HALF_BLOCK);

                    if(IS_TARGET)begin//条件可以写(SOURCE >= 0) && IS_TARGET
                    //但这两个时等价的，保留一个即可
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
    endgenerate

    assign G_out = g_tree[STAGE];
    assign P_out = p_tree[STAGE];

endmodule 
