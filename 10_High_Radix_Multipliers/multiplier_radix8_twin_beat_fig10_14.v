// ============================================================================
// 图 10.14：采用基-8 Booth 重编码的双拍（twin-beat）流水线乘法器
//
// 每一个完整时钟周期被分成两个物理半周期：
//   Beat 1（negedge）：左路 Booth 部分积进入 CSA，并将低 3 位送往小加法器；
//   Beat 2（posedge）：右路 Booth 部分积进入 CSA，并把两个半拍的低位拼成
//                      6 位结果。主从锁存的效果是在同一周期内交错完成两次累加。
//
// 这里仅例化工程中已有的 carry_save_adder 与 k_bit_adder，二者的定义由头文件
// 提供。carry_save_adder 的 carry 输出没有左移，因此本文件在每次寄存器回写时
// 按其“进位权重天然高一位”的物理意义进行相应的算术右移对齐。
// ============================================================================
// ============================================================================
// 模块名称：multiplier_radix8_twin_beat_fig10_14
// 对应教材：Behrooz Parhami《Computer Arithmetic》第 10.5 节
//           Figure 10.14 (Twin-beat multiplier with radix-8 Booth's recoding)
//           Figure 10.15b (Sequential machine with latches and 2-phase clock)
//
// ============================================================================
// 【宏观架构设计心法：我们是怎么一步步构思出图 10.14 架构的？】
//
// 1. 痛点起源 —— 为什么传统的单沿触发器（Fig 10.15a）浪费了一半的时间？
//    在之前实现的 Fig 10.8 / 10.9 / 10.12 存储进位（Carry-Save）乘法器中，虽然我们用
//    CSA 消除了每周期的进位链，但所有的状态寄存器都是在单一时钟沿（posedge clk）触发的。
//    在物理底层，一个标准的边沿触发器（Master-Slave Flip-Flop）内部是由两个电平敏感的
//    锁存器串联而成的：主锁存器（Master Latch）和从锁存器（Slave Latch）。
//    在传统单拍架构中，主、从锁存器之间只有一根导线，导致在整整半个时钟周期里，信号只是
//    干等着穿过锁存器，没有任何算术逻辑在干活，白白浪费了 50% 的时钟周期时间预算！
//
// 2. 破局思路 —— 怎么想到把主从触发器拆成“X 型交叉”的双拍（Twin-Beat）环路？
//    参照图 10.15b 的两相时钟锁存原理：既然主锁存器和从锁存器各自在相反的半个周期里保持
//    数据稳定（一个透明采样时，另一个必然锁死保持），我们干脆把主、从锁存器剪开，在它们
//    中间各塞进一级极快的 CSA 组合逻辑！
//    放到图 10.14 的平面布局上，我们将主锁存器放在左边（left_sum / left_carry，由下降沿
//    negedge clk 锁存），将从锁存器放在右边（right_sum / right_carry，由上升沿 posedge clk
//    锁存）。为了让数据在主、从锁存器之间交替流动，连线自然就画成了“X 型交叉”：
//      - 上半周期（Beat 1，clk = 1，以 negedge clk 结束）：
//        数据从【右边】的 right_sum/carry 出发，斜穿 X 型连线进入【左边 CSA (csa_left)】，
//        加上本周期的第 1 个基-8 倍数（对应乘数低 3 位），在 negedge clk 存入【左边】的
//        left_sum/carry。
//      - 下半周期（Beat 2，clk = 0，以 posedge clk 结束）：
//        刚刚存入【左边】left_sum/carry 的数据，立刻斜穿另一条 X 型连线进入【右边 CSA (csa_right)】，
//        加上本周期的第 2 个基-8 倍数（对应乘数高 3 位），在 posedge clk 存回【右边】的
//        right_sum/carry。
//    如此一来，1 个完整的时钟周期内，部分积像打乒乓球一样在左右两个 CSA 之间弹跳了一个来回
//    （Beat 1 + Beat 2），双倍压榨了时钟上下半周期的算力！
//
// 3. 为什么搭配“基-8 Booth 重编码（预计算 3a）”？
//    - 基-8（Radix-8）每次处理 3 bits 乘数，双拍（Twin-Beat）在 1 个完整时钟周期内就能
//      处理完 3 + 3 = 6 bits 乘数（36 位乘法主循环仅需 36 / 6 = 6 个时钟周期！）。
//    - 基-8 Booth 的数位集是 [-4, +4]，存在唯一的硬倍数 ±3a。如果在主循环里把 3a 拆成
//      2a + a，每拍就要多用一级 CSA；因此我们在启动后的 PRE_CALC 状态花半拍时间预先算好
//      有符号的 3a = 1a + 2a 并锁存起来，使得后续每个半拍（Beat）都只需要 1 级 CSA！
//
// 4. 为什么要做“两处流水线打拍（Pipelining）”？
//    - 第一处（前端 Booth 译码器打拍，对应图 10.14 Booth 方框底部的扁长条矩形）：
//      基-8 Booth 译码与 5 选 1 多路选择器比单级 CSA 慢。为了不让 CSA 等待译码器，我们采用
//      “乒乓错峰预译码”：当左 CSA 在做加法时，右 Booth 正在提前译码下半拍的乘数并在 negedge
//      打拍锁存；当右 CSA 在做加法时，左 Booth 正在提前译码下一周期的乘数并在 posedge 打拍锁存！
//    - 第二处（后端右下角 6-bit 小加法器打拍）：
//      6 位进位传播加法器比 CSA 慢得多。但移入低半区的乘积比特属于“前馈路径（一旦产生就
//      不再回头参与高半区的 CSA 累加）”！因此我们在 6-bit 加法器前端插入一级流水线寄存器
//      （add6_x_pipe / add6_y_pipe），把凑齐的低 6 位数据先打一拍，让 6-bit 加法器在下一个
//      完整周期里从容计算，从而将每个半拍（Beat）的关键路径彻底压缩为纯粹的 1 级 CSA 延迟！
// ============================================================================

`include "carry_save_adder_in_10.v"
`include "k_bit_adder_in_10.v"
`include "radix8_booth_recoder_selector.v"

module multiplier_radix8_twin_beat_fig10_14 #(
    parameter WIDTH = 36  // 参数化位宽，默认为 36 位；应为 6 的整数倍
)(
    input  wire                 clk,          // 系统时钟：negedge 完成 Beat 1，posedge 完成 Beat 2
    input  wire                 rst_n,        // 异步复位，低电平有效
    input  wire                 start,        // 严格单脉冲启动信号
    output wire                 done,         // 完成脉冲
    input  wire [WIDTH-1:0]     multiplicand, // 有符号补码被乘数 a
    input  wire [WIDTH-1:0]     multiplier,   // 有符号补码乘数 x
    output wire [2*WIDTH-1:0]   product       // 2k 位有符号补码乘积
);

    // ========================================================================
    // 一、 内部信号集中声明区
    // 【编码规范思考】：将所有常量函数、parameter、reg、wire 统一前置声明在本区域，
    // 彻底杜绝 Verilog 编译器按自上而下顺序解析时发生“先使用、后声明”导致信号被隐式
    // 推断为 1-bit 标量 wire 的编译报错。
    // ========================================================================

    // ------------------------------------------------------------------------
    // 1. 两个辅助常量函数（为什么不直接用 $clog2 和重复拼接语法？）
    // ------------------------------------------------------------------------
    // 【设计思考 A】：老式标准 Verilog-2001 综合器不支持 SystemVerilog 的 $clog2，
    // 手写常量函数 clog2_int 可保证在任何综合与仿真工具中 100% 兼容。
    function integer clog2_int;
        input integer value;
        integer work;
        begin
            work = value - 1;
            clog2_int = 0;
            while (work > 0) begin
                work = work >> 1;
                clog2_int = clog2_int + 1;
            end
        end
    endfunction

    // 【设计思考 B】：在将 6 位小加法器结果 add6_sum 移入低半区寄存器 pp_low 的最高 6 位时，
    // 常规写法是 {add6_sum, pp_low[WIDTH-1:6]} 或 {{(WIDTH-6){1'b0}}, add6_sum} << (WIDTH-6)。
    // 但如果测试时将参数设为极限情况 WIDTH = 6，pp_low[5:6] 会产生非法的反向切片报错，而
    // {(6-6){1'b0}} 会产生非法的零次重复拼接 {0{1'b0}} 报错！
    // 通过编写逐位赋值的零扩展函数 zero_extend_add6 再左移 (WIDTH-6) 位，即使在 WIDTH = 6 时
    // 也能优雅退化为左移 0 位，不会触发任何语法或 Lint 警告。

    function [WIDTH-1:0] zero_extend_add6;
        input [5:0] value;
        integer bit_index;
        begin
            zero_extend_add6 = {WIDTH{1'b0}};
            for (bit_index = 0; bit_index < 6; bit_index = bit_index + 1) begin
                zero_extend_add6[bit_index] = value[bit_index];
            end
        end
    endfunction

    // ------------------------------------------------------------------------
    // 2. 控制逻辑参数与状态机编码（为什么双拍架构不需要把 WORK 拆成两个状态？）
    // ------------------------------------------------------------------------
    // 【设计思考】：很多初学者会困惑：“每个周期有 Beat 1 和 Beat 2 两拍，状态机是不是也要
    // 设 WORK_BEAT1 和 WORK_BEAT2？” 答案是完全不需要！
    // 因为状态机（state）管理的是“完整时钟周期（posedge 到 posedge）”，在每一个 state == WORK
    // 的完整周期内部，硬件会自动利用中间的 negedge clk 完成 Beat 1 锁存，利用末尾的 posedge clk
    // 完成 Beat 2 锁存。控制通路按周期走，数据通路按半周期走，逻辑最清晰！

    parameter SIXTH_WIDTH = WIDTH / 6; // 每个完整周期消耗乘数的 6 位，WIDTH 必须是 6 的倍数
    // WIDTH=6 时 clog2_int(1)=0，会产生非法的零宽寄存器；用保护条件保证最小 1 位。
    parameter CNT_WIDTH = (SIXTH_WIDTH <= 1) ? 1 : clog2_int(SIXTH_WIDTH); // 保护 WIDTH=6 时位宽至少为 1

    parameter IDLE       = 3'd0; // 空闲状态：等待 start 脉冲，锁存输入操作数 a 和 x
    parameter PRE_CALC   = 3'd1; // 预计算状态（1拍）：negedge 锁存 3a 与乘数初值，下半周期完成第 1 次左路 Booth 预译码并在 posedge 打拍
    parameter WORK       = 3'd2; // 双拍主循环（持续 SIXTH_WIDTH 拍）：每拍完成左、右两次 CSA 累加，并将移出的低 6 位打入小加法器前端流水线
    parameter PIPE_FLUSH = 3'd3; // 流水线排空状态（1拍）：等待被流水线化的 6-bit 小加法器算完最后一组低 6 位乘积并写入 pp_low 和 carry_FF
    parameter MERGE      = 3'd4; // 高半区归并状态（1拍）：用左下角大加法器将最终的 right_sum + right_carry + carry_FF 合并为标准二进制数
    parameter DONE       = 3'd5; // 完成状态（1拍）：拉高 done 信号，输出 2*WIDTH 位最终乘积

    // ------------------------------------------------------------------------
    // 3. 控制寄存器与握手保护线网
    // ------------------------------------------------------------------------

    reg [CNT_WIDTH-1:0]  cnt;          // 记录 WORK 状态已执行的完整双拍周期数
    reg [2:0]            state;        // 当前状态寄存器
    reg [2:0]            next_state;   // 下一状态组合逻辑
    wire                 start_accept; // 仅在 IDLE 状态下响应的受保护启动信号，防止工作期间外部毛刺干扰

    // ------------------------------------------------------------------------
    // 4. 数据通路寄存器（严格区分 posedge 触发与 negedge 触发，严禁跨边沿多驱动！）
    // ------------------------------------------------------------------------

    reg [WIDTH-1:0]   multiplicand_reg; // [posedge] 在 start_accept 时锁存的被乘数 a
    reg [WIDTH-1:0]   multiplier_reg;   // [posedge] 在 start_accept 时同步锁存的乘数 x（避免等到 PRE_CALC 的 negedge 采样时外部总线数据已撤除）
    reg [WIDTH-1:0]   mult_reg;         // [negedge] 顶部乘数移位寄存器（Twin multiplier registers），每周期在 negedge 右移 6 位
    reg               Init0;            // [negedge] 基-8 Booth 重叠扫描所需的最低重叠位 x_{i-1}
    reg [WIDTH+1:0]   mult_3a_reg;      // [negedge] 在 PRE_CALC 的 negedge 锁存的 (k+2) 位有符号 3a

    // X 型交叉 CSA 的左右两组保存进位寄存器（对应图 10.14 中间的左右 Sum / Carry 方框）。
    // 位宽设为 WIDTH+3 位（即 k+3 位），与基-8 Booth 输出的 z_mult 位宽严格一致，确保极值符号守恒。
    reg [WIDTH+2:0]   left_sum;         // [negedge] 左路 CSA 的和锁存器（Beat 1 结束时锁存，供 Beat 2 的右 CSA 使用）
    reg [WIDTH+2:0]   left_carry;       // [negedge] 左路 CSA 的进位锁存器（Beat 1 结束时锁存，供 Beat 2 的右 CSA 使用）
    reg [WIDTH+2:0]   right_sum;        // [posedge] 右路 CSA 的和锁存器（Beat 2 结束时锁存，供下一周期 Beat 1 的左 CSA 使用，并在 MERGE 存最终高半区乘积）
    reg [WIDTH+2:0]   right_carry;      // [posedge] 右路 CSA 的进位锁存器（Beat 2 结束时锁存，供下一周期 Beat 1 的左 CSA 使用）

    // Beat 1（上半周期）从左路 CSA 移出的低 3 列暂存器（在 negedge 锁存，等下半周期与右路移出的高 3 列拼成 6 列）
    reg [2:0]         beat1_sum_low;    // [negedge] 暂存 Beat 1 移出的低 3 位 Sum (第 2, 1, 0 列)
    reg [2:0]         beat1_carry_low;  // [negedge] 暂存 Beat 1 移出的低 2 位 Carry (第 2, 1 列) 与左路负号补偿 extra_dot_left_pipe (第 0 列)

    // 前端基-8 Booth 预译码流水线寄存器（对应图 10.14 左右 Booth 方框最底部的扁长条矩形）
    reg [WIDTH+2:0]   z_left_pipe;          // [posedge] 左路 Booth 倍数反码/原码流水线寄存器（下半周期预译码，posedge 打拍供上半周期左 CSA 用）
    reg               extra_dot_left_pipe;  // [posedge] 左路 Booth 负倍数 +1 补偿点流水线寄存器（权重 8^0 = 2^0，位于第 0 列）
    reg [WIDTH+2:0]   z_right_pipe;         // [negedge] 右路 Booth 倍数反码/原码流水线寄存器（上半周期预译码，negedge 打拍供下半周期右 CSA 用）
    reg               extra_dot_right_pipe; // [negedge] 右路 Booth 负倍数 +1 补偿点流水线寄存器（权重 8^1 = 2^3，位于第 3 列）

    // 右下角 6-bit 小加法器的前端流水线寄存器（切开 CSA 到 6-bit 加法器的组合逻辑关键路径）
    reg [5:0]         add6_x_pipe;      // [posedge] 收集本周期两拍移出的 6 位 Sum（对应图 10.14 标号 6 的输入线）
    reg [5:0]         add6_y_pipe;      // [posedge] 收集本周期两拍移出的 4 位 Carry 与 2 个 extra_dot（对应图 10.14 标号 5 的输入线）
    reg               add6_pipe_valid;  // [posedge] 标记 add6_x/y_pipe 数据有效，指示下一拍将 6-bit 加法结果写入 pp_low

    // 低半区乘积移位寄存器与跨周期进位触发器（对应图 10.14 右下角的 FF 与 To the lower half of partial product）
    reg [WIDTH-1:0]   pp_low;           // [posedge] 存放每次由 6-bit 加法器归并出的非冗余低半区乘积
    reg               carry_FF;

    // ------------------------------------------------------------------------
    // 5. 内部组合逻辑连线 wire
    // ------------------------------------------------------------------------

    // 3a 的两个精确 WIDTH+2 位加数；显式符号扩展可避免隐式截断。
    wire [WIDTH+1:0] multiplicand_ext2;   // 被乘数 a 符号扩展 2 位至 k+2 位 (1a)
    wire [WIDTH+1:0] multiplicand_shift1; // 被乘数 a 符号扩展 1 位并左移 1 位至 k+2 位 (2a)
    wire [WIDTH+1:0] mult_3a_comb;        // 预计算组合逻辑输出的有符号 3a = 1a + 2a

    // 基-8 Booth 预译码结果（z_mult 为 WIDTH+3 位反码形式，extra_dot 为 +1 补偿）。
    wire [WIDTH+2:0] z_left_comb;         // 左路 Booth 子模块组合输出的部分积倍数
    wire             extra_dot_left_comb; // 左路 Booth 子模块组合输出的 +1 补偿点
    wire [WIDTH+2:0] z_right_comb;        // 右路 Booth 子模块组合输出的部分积倍数
    wire             extra_dot_right_comb;// 右路 Booth 子模块组合输出的 +1 补偿点

    // X 型交叉 CSA 的无进位和与进位输出。
    wire [WIDTH+2:0] csa_left_sum;        // 左路 CSA 组合输出的和向量
    wire [WIDTH+2:0] csa_left_carry;      // 左路 CSA 组合输出的进位向量（未左移，第 j 位代表向第 j+1 列的进位）
    wire [WIDTH+2:0] csa_right_sum;       // 右路 CSA 组合输出的和向量
    wire [WIDTH+2:0] csa_right_carry;     // 右路 CSA 组合输出的进位向量（未左移，第 j 位代表向第 j+1 列的进位）

    // 6 位低位归并加法器及最终右半区归并加法器的连线。
    wire [5:0]       add6_sum;            // 右下角 6-bit 加法器算出的 6 位标准二进制乘积
    wire             add6_cout;           // 右下角 6-bit 加法器算出的进位输出（准备存入 carry_FF）
    wire [WIDTH-1:0] add6_shifted;        // 将 add6_sum 移至最高 6 位后的掩码向量
    wire [WIDTH+2:0] adder_sum;           // 左下角最终归并大加法器算出的高半区标准二进制结果

    // ========================================================================
    // 二、 控制逻辑设定：计数器与六状态有限状态机（均由 posedge clk 驱动）
    // ========================================================================

    // 1. 完整双拍周期计数器 cnt
    // 仅在 state == WORK 期间每个 posedge 递增 1；其余状态清零，确保下一次运算从 0 开始计数。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= {CNT_WIDTH{1'b0}};
        end
        else if (state == WORK) begin
            cnt <= cnt + 1'b1;
        end
        else begin
            cnt <= {CNT_WIDTH{1'b0}};
        end
    end

    // 2. 状态机第一段：同步状态转移
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    // 3. 握手保护：仅当状态机处于 IDLE 时才接受外部 start 脉冲
    // 六状态下一状态逻辑。PRE_CALC 与 PIPE_FLUSH、MERGE 各占一个完整周期。
    assign start_accept = start && (state == IDLE);

    // 4. 状态机第二段：下一状态组合逻辑推导
    // 【全流程生命周期推演（以 WIDTH=36 为例，共耗时 1 + 6 + 1 + 1 + 1 = 10 个周期）】：
    //   - IDLE -> PRE_CALC：收到 start_accept，锁存输入 a 和 x。
    //   - PRE_CALC (1拍)：negedge 锁存 3a 和 mult_reg 初值；下半周期左路 Booth 提前译码第 0 组乘数，
    //                     并在周期末 posedge 锁存进 z_left_pipe，无缝衔接 WORK 的第 1 个 Beat 1！
    //   - WORK (6拍，cnt=0~5)：每拍消去 6 bits 乘数，当 cnt == 5 时，36 bits 乘数已在 CSA 中全部累加完毕，
    //                          但最后一组低 6 位数据刚刚打入 add6_x/y_pipe 尚未经 6-bit 加法器求和，故跳入 PIPE_FLUSH。
    //   - PIPE_FLUSH (1拍)：高半区 right_sum/carry 保持不动，等待 6-bit 加法器把最后一组低 6 位算完移入 pp_low，
    //                       并将最后一次进位写入 carry_FF。
    //   - MERGE (1拍)：此时低半区 pp_low 与进位 carry_FF 均已最终就绪，用左下角大 Adder 合并高半区。
    //   - DONE (1拍)：输出 done 脉冲与完整乘积，随后返回 IDLE。
    
    always @(*) begin
        next_state = IDLE;
        case (state)
            IDLE: begin
                if (start_accept) begin
                    next_state = PRE_CALC;
                end
                else begin
                    next_state = IDLE;
                end
            end
            PRE_CALC: begin
                next_state = WORK;
            end
            WORK: begin
                if (cnt == SIXTH_WIDTH-1) begin
                    next_state = PIPE_FLUSH;
                end
                else begin
                    next_state = WORK;
                end
            end
            PIPE_FLUSH: begin
                next_state = MERGE;
            end
            MERGE: begin
                next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // ========================================================================
    // 三、 寄存器设定（第一部分）：posedge clk 驱动（对应 Beat 2 结束瞬间）
    // ========================================================================

    // 1. 输入操作数锁存寄存器（multiplicand_reg 与 multiplier_reg）
    // 【为什么这里要同时锁存 multiplier_reg？】
    // 因为顶层端口约定 start 是“严格单脉冲”，上游主机通常只在 start 为高的那 1 个时钟周期内维持
    // 输入数据有效。由于实际移位寄存器 mult_reg 是在 negedge clk 更新的，不能跨边沿在 posedge 直接写
    // mult_reg（否则会产生多驱动冲突 Multi-driver）。因此我们先在 start_accept 的 posedge 把乘数安全
    // 抓取到过渡寄存器 multiplier_reg 中，半拍后再在 PRE_CALC 的 negedge 转交给 mult_reg！

    // 被乘数只在启动边沿锁存。之后整个乘法过程中保持稳定，供两路 Booth 选择器共享。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            multiplicand_reg <= {WIDTH{1'b0}};
            multiplier_reg   <= {WIDTH{1'b0}};
        end
        else if (start_accept) begin
            multiplicand_reg <= multiplicand;
            // 在同一个启动采样沿锁存乘数，避免等待 PRE_CALC 的 negedge 期间输入改变。
            multiplier_reg   <= multiplier;
        end
    end

    // 2. 左路 Booth 预译码流水线寄存器（z_left_pipe 与 extra_dot_left_pipe）
    // 【对应图 10.14 左侧 Booth 方框底部的扁长条矩形】：
    // 在 PRE_CALC 或 WORK 状态的下半周期（clk = 0）里，左路 booth_left 已经提前对着下一周期要用的
    // 乘数低位窗口 {mult_reg[2:0], Init0} 完成了译码；在周期末的 posedge clk 将其打拍锁存，
    // 这样到了下一周期上半拍（Beat 1，clk = 1），左路 csa_left 一上来就能直接使用稳定的 z_left_pipe！

    // PRE_CALC 打入首个低 3 位窗口，WORK 每拍打入下一个窗口。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            z_left_pipe        <= {(WIDTH+3){1'b0}};
            extra_dot_left_pipe <= 1'b0;
        end
        else if ((state == PRE_CALC) || (state == WORK)) begin
            z_left_pipe        <= z_left_comb;
            extra_dot_left_pipe <= extra_dot_left_comb;
        end
    end

    // 3. 右路 CSA 保存进位寄存器（right_sum 与 right_carry）
    // 【有符号 CSA 算术右移 3 位（除以 8）的位宽守恒推导 —— 为什么 Sum 右移 3 位，而 Carry 只右移 2 位？】
    //   - 我们的 CSA 位宽为 M = WIDTH + 3 位（索引 [WIDTH+2 : 0]），处理的是二进制补码有符号数。
    //   - 根据有符号补码 CSA 定理：第 WIDTH+2 列（最高位，权重为负的 -2^(WIDTH+2)）全加器满足
    //     -(x + y + z)*2^(WIDTH+2) = -sum[WIDTH+2]*2^(WIDTH+2) - carry[WIDTH+2]*2^(WIDTH+3)。
    //     也就是说，csa_right_sum[WIDTH+2] 是和向量的符号位，而 csa_right_carry[WIDTH+2] 是进位向量的符号位！
    //   - 在 Beat 2 结束时，部分积需要算术右移 3 位（除以基数 8）：
    //     (a) 对于 csa_right_sum：低 3 位 [2:0] 被切走送往右下角 6-bit 小加法器；剩下的高 WIDTH 位
    //         [WIDTH+2:3] 右移 3 位后，最高位空出 3 位，因此必须复制 3 次自身的符号位 csa_right_sum[WIDTH+2]
    //         进行算术符号扩展，即 {{3{csa_right_sum[WIDTH+2]}}, csa_right_sum[WIDTH+2:3]}！
    //     (b) 对于 csa_right_carry：由于子模块 carry_save_adder 没有在内部把 carry 左移，物理索引第 j 位的
    //         carry[j] 天然代表第 j+1 列的权重（即天生已经乘以了 2）！既然天生已经左移了 1 位（×2），
    //         现在要实现除以 8（÷8），在物理索引上就只需要右移 2 位（÷4，合起来 2 ÷ 8 = 1/4？不对，原本第 j 位
    //         权重是 2^(j+1)，除以 8 后权重变为 2^(j-2)，即原来索引 2 的位（权重 2^3=8）除以 8 后变为权重 2^0=1，
    //         应该落入新寄存器的索引 0）！因此，仅低 2 位 [1:0] 被切走送往 6-bit 小加法器，剩下的高 WIDTH+1 位
    //         [WIDTH+2:2] 右移 2 位后，最高位空出 2 位，复制 2 次自身的符号位 csa_right_carry[WIDTH+2] 即可！
    
    // CSA 的 carry 物理上权重高一位，因而右移时使用与左路相同的“sum 右移 3、carry 右移 2”对齐规则。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            right_sum   <= {(WIDTH+3){1'b0}};
            right_carry <= {(WIDTH+3){1'b0}};
        end
        else if (start_accept) begin
            right_sum   <= {(WIDTH+3){1'b0}};
            right_carry <= {(WIDTH+3){1'b0}};
        end
        else if (state == WORK) begin
            right_sum   <= {{3{csa_right_sum[WIDTH+2]}}, csa_right_sum[WIDTH+2:3]};
            right_carry <= {{2{csa_right_carry[WIDTH+2]}}, csa_right_carry[WIDTH+2:2]};
        end
        else if (state == MERGE) begin
            right_sum   <= adder_sum;
            right_carry <= {(WIDTH+3){1'b0}};
        end
    end

    // 4. 右下角 6-bit 小加法器前端流水线寄存器（add6_x_pipe, add6_y_pipe, add6_pipe_valid）
    // =========================================================================
    // 【全图最精妙硬件设计：为什么图 10.14 右下角标着 6 和 5？两个 extra_dot 怎么零成本塞进去的？】
    // 每一个完整 WORK 周期共移出 6 列低位数据（第 5 列 ~ 第 0 列，权重 2^5 ~ 2^0）：
    //   - 第 2 ~ 0 列来自上半拍（Beat 1，negedge 已暂存在 beat1_sum_low 和 beat1_carry_low 中）；
    //   - 第 5 ~ 3 列来自下半拍（Beat 2，当前 csa_right 正在输出的低位）。
    // 我们将这 6 列的位权排成下表，就能一目了然地看到两个“天然空槽”：
    //
    // | 比特列（相对权重） | 第5列(2^5) | 第4列(2^4) | 第3列(2^3=8^1) | 第2列(2^2) | 第1列(2^1) | 第0列(2^0=8^0) |
    // |--------------------|------------|------------|----------------|------------|------------|----------------|
    // | add6_x_pipe (标6)  | right_s[2] | right_s[1] |   right_s[0]   | left_s[2]  | left_s[1]  |   left_s[0]    |
    // | 原始 CSA Carry     | right_c[1] | right_c[0] |  【天然空缺!】 | left_c[1]  | left_c[0]  |  【天然空缺!】 |
    // | add6_y_pipe (标5)  | right_c[1] | right_c[0] | extra_dot_right| left_c[1]  | left_c[0]  | extra_dot_left |
    // | add6_inst 的 .cin  |     -      |     -      |       -        |     -      |     -      |    carry_FF    |
    //
    // 【为什么第 0 列和第 3 列的原始 Carry 天然是空的？】
    //   1. 第 0 列：因为 csa_left_carry[0] 是第 0 列向第 1 列的进位（位于第 1 列），第 0 列本身没有来自更低位的
    //      CSA 进位，所以天然空缺！而左路负倍数求补的 +1 补偿点 extra_dot_left_pipe 权重正好是 8^0 = 2^0（第 0 列），
    //      刚好严丝合缝地填进第 0 列空槽！
    //   2. 第 3 列：Beat 1 产生的第 3 列进位 csa_left_carry[2] 已经在 negedge 时右移 2 位变成了 left_carry[0]，
    //      送进右路 csa_right 的第 0 位（即全局第 3 列）参与了下半拍的压缩！而右路 csa_right 自己产生的最低位进位
    //      csa_right_carry[0] 是向第 4 列进位的（位于第 4 列）！因此第 3 列的 Carry 位置又天然空出来了！
    //      而右路负倍数求补的 +1 补偿点 extra_dot_right_pipe 权重正好是 8^1 = 2^3（第 3 列），又分毫不差地填进第 3 列空槽！
    // =========================================================================

    // 拼接两个半拍的低位冗余数据。x 线承载两个 CSA sum 的 3 位片段；y 线承载两个 CSA carry 的 2 位片段，
    // 以及右路 extra_dot 和左路 extra_dot 所占的两个天然空槽。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            add6_x_pipe     <= 6'b0;
            add6_y_pipe     <= 6'b0;
            add6_pipe_valid <= 1'b0;
        end
        else if (state == WORK) begin
            add6_x_pipe     <= {csa_right_sum[2:0], beat1_sum_low};
            add6_y_pipe     <= {csa_right_carry[1:0], extra_dot_right_pipe, beat1_carry_low};
            add6_pipe_valid <= 1'b1;
        end
        else begin
            // PIPE_FLUSH 仍会消费上一个 WORK 拍的 valid，但不再写入新的前端数据。
            add6_pipe_valid <= 1'b0;
        end
    end

    // 5. 低半区乘积移位寄存器（pp_low）与跨周期进位触发器（carry_FF）
    // 当 add6_pipe_valid 为 1 时（涵盖 WORK 的第 2 拍直到 PIPE_FLUSH 拍），将 6-bit 加法器算出的
    // 6 位非冗余乘积移入 pp_low 的最高 6 位，原有低位右移 6 位；同时将进位输出存入 carry_FF。

    // 每次有效 6 位结果代表乘数的三个 Booth 位组，新得到的 6 位被放入高端，原有结果向低端移动 6 位。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pp_low   <= {WIDTH{1'b0}};
            carry_FF <= 1'b0;
        end
        else if (start_accept) begin
            pp_low   <= {WIDTH{1'b0}};
            carry_FF <= 1'b0;
        end
        else if (add6_pipe_valid) begin
            // 将 6 位新结果移到低半区的最高 6 位，再与旧值逻辑右移 6 位合并。
            // 该写法与 {add6_sum, pp_low[WIDTH-1:6]} 完全等价，并且 WIDTH=6
            // 时不会生成非法的 [5:6] 反向位选。
            pp_low   <= add6_shifted | (pp_low >> 6);
            carry_FF <= add6_cout;
        end
    end

    // ========================================================================
    // 四、 寄存器设定（第二部分）：negedge clk 驱动（对应 Beat 1 结束瞬间）
    // ========================================================================

    // 1. 有符号 3a 预计算锁存器（mult_3a_reg）
    // 在 PRE_CALC 状态的上半周期（clk = 1），组合逻辑算出 3a = 1a + 2a，并在 PRE_CALC 中间的
    // negedge clk 锁存进 mult_3a_reg。这样在 PRE_CALC 的下半周期（clk = 0），左路 booth_left
    // 就能立刻使用稳定的 3a 完成第一次预译码！

    // 先把 a 符号扩展到 k+2 位，再与左移一位的 2a 相加。
    // 该寄存器在 PRE_CALC 的半周期末锁存，使整个 WORK 阶段的 Booth 组合逻辑稳定。
    always @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_3a_reg <= {(WIDTH+2){1'b0}};
        end
        else if (state == PRE_CALC) begin
            mult_3a_reg <= mult_3a_comb;
        end
    end

    // 2. 左路 CSA 锁存器（left_sum, left_carry）与 Beat 1 低 3 位暂存器（beat1_sum_low, beat1_carry_low）
    // 在 WORK 状态的每个 negedge clk（Beat 1 结束瞬间）：
    //   - 将左路 csa_left 的高半区结果算术右移 3 位（除以 8）存入 left_sum 和 left_carry，立刻跨过
    //     X 型交叉线供下半周期（Beat 2）的右路 csa_right 累加；
    //   - 将移出的低 3 列暂存进 beat1_sum_low 和 beat1_carry_low，等下半周期结束时与右路拼成 6 位。

    // csa_left_sum 的第 0~2 列转移到 6 位加法器的低半拍；
    // 高位部分算术右移 3 位，相当于除以 radix-8 的 8，并用符号位保持补码真值。
    // csa_left_carry 已经隐含左移一位，故只需右移 2 位即可达到同样的 /8 权重。
    always @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            left_sum       <= {(WIDTH+3){1'b0}};
            left_carry     <= {(WIDTH+3){1'b0}};
            beat1_sum_low  <= 3'b0;
            beat1_carry_low <= 3'b0;
        end
        else if (state == WORK) begin
            left_sum       <= {{3{csa_left_sum[WIDTH+2]}}, csa_left_sum[WIDTH+2:3]};
            left_carry     <= {{2{csa_left_carry[WIDTH+2]}}, csa_left_carry[WIDTH+2:2]};
            beat1_sum_low  <= csa_left_sum[2:0];
            // carry 的两列与左路 extra_dot 共同占据小加法器的低三列。
            beat1_carry_low <= {csa_left_carry[1:0], extra_dot_left_pipe};
        end
    end

    // 3. 右路 Booth 预译码流水线寄存器（z_right_pipe, extra_dot_right_pipe）与顶部乘数移位寄存器（mult_reg, Init0）
    // 【为什么乘数寄存器 mult_reg 要在 negedge clk 右移 6 位，而不是在 posedge clk？】
    // 这是实现“乒乓错峰预译码”最巧妙的时序咬合点：
    //   - 在 PRE_CALC 的 negedge clk：mult_reg 载入乘数初值 multiplier_reg，Init0 清零。
    //   - 紧接着在 PRE_CALC 的下半周期（clk = 0）：左路 booth_left 扫描低位窗口 {mult_reg[2:0], Init0}，
    //     并在进入 WORK 的 posedge clk 打拍锁存进 z_left_pipe（此时低位窗口任务已完成！）。
    //   - 随后在 WORK 的上半周期（clk = 1，Beat 1）：右路 booth_right 扫描高位窗口 mult_reg[5:2]。
    //   - 到了 WORK 的 negedge clk：右路把译码结果锁存进 z_right_pipe（此时本周期 6 位乘数 mult_reg[5:0]
    //     已经全部被左右两个 Booth 译码器消费完毕！）。因此，就在这同一个 negedge clk，我们立刻将
    //     mult_reg 右移 6 位，并把移出的最高位 mult_reg[5] 存入 Init0！
    //   - 这样一进入 WORK 的下半周期（clk = 0，Beat 2），左路 booth_left 看到的 {mult_reg[2:0], Init0}
    //     就已经自动变成了【下一个周期】的低位窗口，从而能在下半周期提前完成下一周期的预译码！

    // 右路 Booth 预译码及乘数移位均在 negedge 完成。mult_reg >> 6 是精确的
    // 逻辑右移（乘数视为无符号位串），不会在 WIDTH=6 时产生非法零宽切片。
    always @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            z_right_pipe         <= {(WIDTH+3){1'b0}};
            extra_dot_right_pipe <= 1'b0;
            mult_reg             <= {WIDTH{1'b0}};
            Init0                <= 1'b0;
        end
        else if (state == PRE_CALC) begin
            // 预计算半周期载入已在 start 的 posedge 锁存的乘数，供下一个 WORK 的
            // 两个 Booth 窗口使用。这样外部数据在启动沿之后即可安全撤销或改变。
            mult_reg <= multiplier_reg;
            Init0    <= 1'b0;
        end
        else if (state == WORK) begin
            z_right_pipe         <= z_right_comb;
            extra_dot_right_pipe <= extra_dot_right_comb;
            // 右移 6 位：本周期消费 x[5:0]，保留 x[WIDTH-1:6] 供后续周期。
            mult_reg <= mult_reg >> 6;
            // 新的 x_{-1} 是刚刚移出的第 5 位（下一低窗口的重叠位）。
            Init0    <= mult_reg[5];
        end
    end

    // ========================================================================
    // 五、 子模块例化与组合数据通路
    // ========================================================================

    // 1. 有符号硬倍数 3a = 1a + 2a 的组合逻辑计算（对齐在 WIDTH+2 位，防溢出）

    // 3a 组合预计算。两项均已是 WIDTH+2 位，避免 Verilog 表达式的隐式扩展。
    assign multiplicand_ext2  = {{2{multiplicand_reg[WIDTH-1]}}, multiplicand_reg};
    assign multiplicand_shift1 = {multiplicand_reg[WIDTH-1], multiplicand_reg, 1'b0};
    assign mult_3a_comb       = multiplicand_ext2 + multiplicand_shift1;

    // 2. 将 6-bit 小加法器输出零扩展并移至 WIDTH 位向量的最高 6 位

    // 6 位加法结果占据 pp_low 的最高 6 位；先显式扩展到 WIDTH 位，再左移 WIDTH-6。
    // WIDTH=6 时移位量为 0，因此自然退化为 add6_sum，不会出现非法位选或零重复。
    assign add6_shifted = zero_extend_add6(add6_sum) << (WIDTH-6);

    // 3. 例化左、右两个基-8 Booth 重编码与倍数选择器（对应图 10.14 顶部的两个大方框）
    //    - 左路窗口：{mult_reg[2:0], Init0}（共 4 bits，权重 8^0 = 1）
    //    - 右路窗口：mult_reg[5:2]（共 4 bits，权重 8^1 = 8，其中 mult_reg[2] 为左右共享的重叠扫描位）

    // 基-8 Booth 的两个重叠窗口：左路使用低 3 位及 Init0，右路使用高 3 位。
    radix8_booth_recoder_selector #(
        .WIDTH(WIDTH)
    ) booth_left (
        .a(multiplicand_reg),
        .a_3(mult_3a_reg),
        .x_quartet({mult_reg[2:0], Init0}),
        .z_mult(z_left_comb),
        .extra_dot(extra_dot_left_comb)
    );

    radix8_booth_recoder_selector #(
        .WIDTH(WIDTH)
    ) booth_right (
        .a(multiplicand_reg),
        .a_3(mult_3a_reg),
        .x_quartet(mult_reg[5:2]),
        .z_mult(z_right_comb),
        .extra_dot(extra_dot_right_comb)
    );

    // 4. 例化中间呈 X 型交叉连接的左、右两个保留进位加法器（CSA）
    //    - 左 CSA (csa_left，上半拍工作)：吃【右边】的 right_sum / right_carry 与左路已打拍的 z_left_pipe；
    //    - 右 CSA (csa_right，下半拍工作)：吃【左边】的 left_sum / left_carry 与右路已打拍的 z_right_pipe。

    // X 型交叉连接：左路将右 CSA 的保存状态与新的左部分积相加，
    // 右路将左 CSA 的保存状态与新的右部分积相加，两个半拍交替前进。
    carry_save_adder #(
        .WIDTH(WIDTH+3)
    ) csa_left (
        .x(right_sum),
        .y(right_carry),
        .z(z_left_pipe),
        .sum(csa_left_sum),
        .carry(csa_left_carry)
    );

    carry_save_adder #(
        .WIDTH(WIDTH+3)
    ) csa_right (
        .x(left_sum),
        .y(left_carry),
        .z(z_right_pipe),
        .sum(csa_right_sum),
        .carry(csa_right_carry)
    );

    // 5. 例化右下角流水线化的 6-bit 小加法器（对应图 10.14 右下角的 6-bit adder）
    //    负责在每个周期将上一拍打入 add6_x_pipe 和 add6_y_pipe 的冗余低 6 位连同 carry_FF 合并为标准二进制数。

    // 右下角 6 位加法器。carry_FF 是上一拍的模进位，作为 cin 进入第 0 列。
    k_bit_adder #(
        .WIDTH(6)
    ) add6_inst (
        .x(add6_x_pipe),
        .y(add6_y_pipe),
        .cin(carry_FF),
        .sum(add6_sum),
        .cout(add6_cout)
    );

    // 6. 例化左下角最终归并大加法器（对应图 10.14 左下角的 Adder）
    //    仅在最后 MERGE 状态使用，将高半区最终残留的 right_sum + right_carry + carry_FF 合并为标准二进制数。

    // MERGE 状态的最终右半区归并：right_sum + right_carry + carry_FF。
    k_bit_adder #(
        .WIDTH(WIDTH+3)
    ) adder_inst (
        .x(right_sum),
        .y(right_carry),
        .cin(carry_FF),
        .sum(adder_sum),
        .cout()
    );

    // ========================================================================
    // 六、 顶层输出逻辑
    // ========================================================================

    assign done    = (state == DONE);
    
    // MERGE 归并完成后，right_sum 的低 WIDTH 位即为高半区最终乘积，与低半区 pp_low 拼接成 2*WIDTH 位乘积。
    // right_sum 的低 WIDTH 位是高半区最终乘积；pp_low 是低半区移位结果。
    assign product = {right_sum[WIDTH-1:0], pp_low};

endmodule

