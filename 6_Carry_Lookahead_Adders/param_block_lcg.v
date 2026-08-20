//本架构参见Fig6.3
module param_block_lcg #(
    parameter NUM_BLOCKS = 4  // 泛化：支持任意数量的 Block 组合，默认如图6.3所示为4
)(
    // 输入端
    input  [NUM_BLOCKS-1:0] g_in,  // 各个块的产生信号 (对应图中竖向的 g)
    input  [NUM_BLOCKS-1:0] p_in,  // 各个块的传递信号 (对应图中竖向的 p)
    input                   cin,   // 初始进位 (对应图中的 c_i0)

    // 输出端
    output [NUM_BLOCKS-2:0] cout,  // 中间进位输出 (对应图中的 c_j0+1, c_j1+1, c_j2+1)
    output                  G_out, // 整个超大块的全局产生信号
    output                  P_out  // 整个超大块的全局传递信号
);

// 内部线网：用于存放从第 0 块到第 i 块的累积前缀状态
    wire [NUM_BLOCKS-1:0] G_prefix;
    wire [NUM_BLOCKS-1:0] P_prefix;

    // 1. 初始化第 0 个块的前缀状态 (边界条件)
    assign G_prefix[0] = g_in[0];
    assign P_prefix[0] = p_in[0];

    // 2. 利用 generate for 循环展开递推逻辑
    genvar i;
    generate
        for (i = 1; i < NUM_BLOCKS; i = i + 1) begin : gen_prefix
            // 当前块产生进位，或者当前块传递了前面累积的进位
            assign G_prefix[i] = g_in[i] | (p_in[i] & G_prefix[i-1]);
            // 当前块必须传递，且前面的块也必须传递
            assign P_prefix[i] = p_in[i] & P_prefix[i-1];
        end
    endgenerate

    // 3. 计算中间进位 cout (对应图中的那些倒勾箭头)
    // 根据图 6.3，第 i 块输出的进位 c_{j_i+1}，等于累积 G_prefix 融合初始 cin
    generate
        for (i = 0; i < NUM_BLOCKS - 1; i = i + 1) begin : gen_cout
            assign cout[i] = G_prefix[i] | (P_prefix[i] & cin);
        end
    endgenerate

    // 4. 整体超级大块的输出 (最高位的累积结果)
    assign G_out = G_prefix[NUM_BLOCKS-1];
    assign P_out = P_prefix[NUM_BLOCKS-1];

endmodule

//对于Fig6.3，LCG的逻辑公式在“位”级别与“块”级别完全同构
//那么如何处理任意宽度和重叠呢？
//它们在Top层（顶层例化）的数据连线里
//举个例子，假设你要计算一个16位的加法，你想将其分成四个重叠的块
//比如：0~4, 4~8, 8~12, 12~15，注意端点有重叠:

// module sixteen_bits_adder(
//     input [15:0] A,
//     input [15:0] B,
//     input        global_in,

//     output [15:0] sum,
//     output        global_out
// );
// // 在顶层模块中
// wire [3:0] block_g, block_p;

// // 通过调用底层的块生成器（这部分你需要另外写一个简单的小模块），
// // 传入不规则的位宽切片，强行构造出重叠效果！
// block_generator u_blk0 (.a(A[4:0]),   .b(B[4:0]),   .g_out(block_g[0]), .p_out(block_p[0]));
// block_generator u_blk1 (.a(A[8:4]),   .b(B[8:4]),   .g_out(block_g[1]), .p_out(block_p[1]));
// block_generator u_blk2 (.a(A[12:8]),  .b(B[12:8]),  .g_out(block_g[2]), .p_out(block_p[2]));
// block_generator u_blk3 (.a(A[15:12]), .b(B[15:12]), .g_out(block_g[3]), .p_out(block_p[3]));

// // 最后，把你写好的通用 LCG 例化进来！
// param_block_lcg #(.NUM_BLOCKS(4)) u_master_lcg (
//     .g_in(block_g),
//     .p_in(block_p),
//     .cin(global_cin),
//     //连出 cout, G_out, P_out
//     //...
// );

// //完成剩余部分对global_out与sum的计算
// //...
// endmodule