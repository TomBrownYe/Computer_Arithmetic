//本模块为Fig8.4的一般化形式，即对应的n个k位无符号操作数的求和器
`include "ripple_adder.v"

module tree_multioperand_adder #(
    parameter N = 7, // 操作数的个数 (对应图8.4中的7个数)
    parameter K = 8  // 初始操作数的位宽
) (
    // 将 N 个 K 位宽的操作数拼接展平为一维向量输入
    input  wire [N*K-1:0] data_in,
    
    // 输出总和位宽自动计算为 K + ceil(log2(N))
    output wire [K+$clog2(N)-1:0] sum_out
);

    localparam STAGE = $clog2(N); //树状加法器层数
    localparam MAX_WIDTH = K + STAGE; //最大宽度

    // 二维数组：[位宽]tree_data[层级][节点索引]
    // 统一分配最大位宽（MAX_WIDTH)以及最大节点（N），避免动态位宽与节点声明导致的语法错误
    wire [MAX_WIDTH-1:0] tree_data [0:STAGE][0:N-1];

    genvar idx,level,unused;
    generate
        // 1. 初始化第0层（叶子节点），解包一维输入向量并进行高位补零
        for(idx = 0; idx < N; idx = idx + 1)begin:gen_init
            assign tree_data[0][idx] = {{MAX_WIDTH-K{1'b0}},data_in[idx*K+:K]};
        end

        // 2. 逐层构建加法树
        for(level = 0; level < STAGE; level = level + 1)begin:gen_level
            localparam NODES_NUM = (N + (2 ** level) - 1) / (2 ** level); // 每层节点数
            localparam CUR_WIDTH = K + level; // 当前层级宽度
            localparam PAIRS = NODES_NUM / 2;
            localparam ODD = NODES_NUM % 2;
            localparam NEXT_NODES_NUM = PAIRS + ODD;
            // 2.1 实例化成对的加法器
            for(idx = 0; idx < PAIRS; idx = idx + 1)begin:gen_adder
                ripple_adder #(.W(CUR_WIDTH)) u_adder(
                    .a(tree_data[level][2*idx][CUR_WIDTH-1:0]),
                    .b(tree_data[level][2*idx+1][CUR_WIDTH-1:0]),
                    .sum(tree_data[level+1][idx][CUR_WIDTH:0])
                );
                
                // 将求出的和所在的节点的未使用的高位强制接地，防止综合出锁存器或 X 态传播
                if(CUR_WIDTH + 1 < MAX_WIDTH)begin:pad_adder
                    assign tree_data[level+1][idx][MAX_WIDTH-1:CUR_WIDTH+1] = 0;
                end
            end

            // 2.2 处理奇数个节点的情况
            if(ODD)begin:gen_bypass
                assign tree_data[level+1][PAIRS][CUR_WIDTH:0] = {1'b0,tree_data[level][NODES_NUM-1][CUR_WIDTH - 1:0]};

                // 旁路节点的高位也需要补零
                if(CUR_WIDTH + 1 < MAX_WIDTH)begin:pad_bypass
                    assign tree_data[level+1][PAIRS][MAX_WIDTH-1:CUR_WIDTH+1] = 0;
                end
            end

            // 2.3 将本层计算输出（level+1）未用到的多余节点予以归零，注意分号和起点
            for(unused = NEXT_NODES_NUM; unused < N; unused = unused + 1)begin:gen_zero
                assign tree_data[level+1][unused] = {MAX_WIDTH{1'b0}};
            end
        end
    endgenerate

    // 3. 输出总和
    assign sum_out = tree_data[STAGE][0][MAX_WIDTH-1:0];

endmodule