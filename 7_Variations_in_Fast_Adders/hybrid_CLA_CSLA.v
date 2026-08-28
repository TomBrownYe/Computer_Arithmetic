// 混合架构：超前进位(BK树) / 选择进位加法器
`include "BK_prefix_tree_in_7.v"

module hybrid_cla_csla #(
    parameter N = 16, // 宏块的数量 (Macro-blocks)
    parameter M = 4   // 每个宏块的位宽 (Bits per block)
)(
    input  wire [N*M - 1 : 0] x,
    input  wire [N*M - 1 : 0] y,
    input  wire               cin,
    output wire [N*M - 1 : 0] sum,
    output wire               cout
);

    // 1. 内部信号声明
    // 存储所有宏块在 cin=0 和 cin=1 时的预计算结果
    wire [M-1:0] sum0_blk [0:N-1];
    wire [M-1:0] sum1_blk [0:N-1];
    wire [N-1:0] cout0_blk;
    wire [N-1:0] cout1_blk;

    // 块级 G 和 P 信号 (用于喂给顶层 BK 树)
    wire [N-1:0] block_G;
    wire [N-1:0] block_P;

    // 顶层 BK 树计算出的全局进位 (Global true carries)
    wire [N-1:0] true_carry;   // BK 树输出的 G就是真实的进位，因为我们在Block0时做了预处理，预先吸收了cin
    wire [N-1:0] unused_P_out; // BK树输出的P通常用于更高层级扩展，单模块可悬空
                               // 但由于我们设置了block_P[0]=0，带入前缀树级联公式可以得到unused_P_out是全0的
                               // P信号全0的物理意义：P的本质是向上传播的进位通道，而Block0由于被提前吸收了，没有向上传播的进位，所以P=0。
                               // cin的预先吸收，使得其不再是被传播的进位，而是实际参与了运算，融入了由Block0计算出的自身生成的进位，进位穿透通道自然关闭。
    // 2. 底层宏块阵列 (Carry-Select Blocks)
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : gen_macro_blocks
            
            // 提取当前宏块的输入切片
            wire [M-1:0] curr_x = x[i*M +: M];
            wire [M-1:0] curr_y = y[i*M +: M];

            if (i == 0) begin
               
                // 【特殊边界】Block 0: 直接接收全局 cin，不需要备胎和 MUX
                // 直接算出唯一真实的 sum 和 cout
                assign {cout0_blk[0], sum0_blk[0]} = curr_x + curr_y + cin;
                
                // 将结果直接接到全局输出
                assign sum[0 +: M] = sum0_blk[0];
                
                // Block 0 的 G 就是它真实的 cout。P 设为 0 (因为它不再需要向上传播别人)
                assign block_G[0] = cout0_blk[0];
                assign block_P[0] = 1'b0; 
            end 
            
            else begin
                
                // 【常规宏块】Block 1 ~ N-1: 并行计算 0/1 两套结果
                // 强制调用综合工具内部最优化的 RCA 逻辑
                assign {cout0_blk[i], sum0_blk[i]} = curr_x + curr_y + 1'b0;
                assign {cout1_blk[i], sum1_blk[i]} = curr_x + curr_y + 1'b1;
                
                // 顶级 Trick：提取块级 G 和 P
                //如果一个底层宏块计算了cin=0的进位输出 cout0，以及cin=1的进位输出 cout1。
                //那么，块级生成信号G = cout0，块级传播信号P = cout1。
                //证明：字面意思，如果cin=0还能产生进位，那么其自身肯定产生了进位，即G=1
                //如果cin=1产生了进位，那么要么其自己产生了进位，要么把进位传播了出去，即P=1
                assign block_G[i] = cout0_blk[i];
                assign block_P[i] = cout1_blk[i];
                
                // 根据 BK 树算出的前一级真实进位，MUX 选出最终和
                assign sum[i*M +: M] = true_carry[i-1] ? sum1_blk[i] : sum0_blk[i];
            end
        end
    endgenerate

    // 3. 顶层路由网络 (Lookahead Carry Generator - BK Tree)
    // 注意：这里的 BK 树处理的位宽是宏块的数量 N，而不是总位宽 N*M！
    BK_prefix_tree #(
        .WIDTH(N)
    ) lcg_tree_inst (
        .g_in (block_G), 
        .p_in (block_P), 
        .G_out(true_carry),   // 算出的每个宏块产生的绝对进位
        .P_out(unused_P_out)
    );

    // 4. 终局输出
    // 整个加法器的最终进位输出，就是最后一个宏块 (N-1) 的绝对进位
    assign cout = true_carry[N-1];

endmodule