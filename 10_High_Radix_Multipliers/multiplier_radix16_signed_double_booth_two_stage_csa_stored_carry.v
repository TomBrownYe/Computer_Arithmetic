// 本架构参见 Fig 10.11 + Fig 10.10 (10.4节练习)：
// 采用双 Booth 重编码子模块与两级 CSA 树的有符号基-16 存储进位右移乘法器
`include "k_bit_adder_in_10.v"
`include "carry_save_adder_in_10.v"
`include "Booth_recoder_and_selector.v"

module multiplier_radix16_signed_double_booth_two_stage_csa_stored_carry #(
    parameter WIDTH = 32  // 参数化位宽，默认为 32 位（需为 4 的倍数）
)(
    input  wire                 clk,          // 系统时钟
    input  wire                 rst_n,        // 异步复位（低电平有效）
    
    // 控制/握手信号
    input  wire                 start,        // 乘法启动信号（严格单脉冲）
    output wire                 done,         // 乘法完成信号（脉冲有效）
    
    // 数据输入
    input  wire [WIDTH-1:0]     multiplicand, // 有符号补码被乘数 (a)
    input  wire [WIDTH-1:0]     multiplier,   // 有符号补码乘数 (x)
    
    // 数据输出
    output wire [2*WIDTH-1:0]   product       // 2k位有符号补码乘积 (p)
);
    // 内部信号
        // 控制逻辑设定

            // 计数器
                parameter QUARTER_WIDTH = WIDTH / 4;
                parameter CNT_WIDTH = $clog2(QUARTER_WIDTH); // 计数器位宽
                reg [CNT_WIDTH-1:0] cnt; // 计数器

            // 有限状态机
                parameter IDLE  = 0; // 空闲状态
                parameter WORK  = 1; // 工作状态
                parameter MERGE = 2; // 合并状态（持续1拍，用底部的k位加法器将最后残留的pp_sum和pp_carry以及FF中的进位合并）
                parameter DONE  = 3; // 完成状态
                reg[1:0] state, next_state; // 当前状态与下一状态

        // 寄存器设定

            // 被乘数寄存器
                reg [WIDTH-1:0] multiplicand_reg; // 锁存的被乘数

            // 低半区共享移位寄存器pp_low
                reg [WIDTH-1:0] pp_low; // 低半区共享移位寄存器

            // 存储低位寄存器，保留最低位被移出去的x_i-1
                reg Init0; // 保存移出乘数的最低位

            // 4位加法器存储进位寄存器（carry-FF），用于存储上一次的进位输出
                reg carry_FF; // 4 位加法器的进位寄存器

            // 高半区pp_sum寄存器
                reg [WIDTH+3:0] pp_sum; // 高半区部分积和寄存器

            // 高半区pp_carry寄存器
                reg [WIDTH+3:0] pp_carry; // 高半区部分积进位寄存器
            
        // Booth recoder & selector；Booth 重编码器和倍数选择器
        // Booth 重编码器与倍数选择器

            wire [WIDTH+1:0] z_mult0,z_mult1; // Booth 选择器输出的部分积
            wire extra_dot0,extra_dot1; // 负倍数对应的额外进位补偿，前者权重为1，后者为4

        // CSA；进位保存加法器

            wire [WIDTH+3:0] csa1_sum, csa1_carry;
            wire [WIDTH+4:0] csa2_sum, csa2_carry;

        // 4位加法器

            wire [3:0] add4_sum; // 4位加法器的和
            wire add4_cout;      // 24位加法器的进位

        // k+4位合并加法器

            wire [WIDTH+3:0] adder_sum;  // k+4位合并加法器的和
            wire             adder_cout; // k+4位补码合并加法器的模进位输出（直接丢弃）
    
    // 控制逻辑设定
        // 计数器
            always@(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    cnt <= {CNT_WIDTH{1'b0}};
                end
                else if(state == WORK)begin
                    cnt <= cnt + 1'b1;
                end
                else begin
                    cnt <= {CNT_WIDTH{1'b0}};
                end
            end

        // 有限状态机
            always@(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    state <= IDLE;
                end
                else begin
                    state <= next_state;
                end
            end

            always@(*) begin
                case(state)
                    IDLE: begin
                        if(start) begin
                            next_state = WORK; // 无需预计算 3a，直接开始工作
                        end
                        else begin
                            next_state = IDLE;
                        end
                    end
                    WORK: begin
                        if(cnt == QUARTER_WIDTH-1) begin
                                next_state = MERGE; // 进入合并状态
                        end
                        else begin
                            next_state = WORK;
                        end
                    end
                    MERGE: begin
                        next_state = DONE; // 合并状态持续1拍，直接进入完成状态
                    end
                    DONE: begin
                        next_state = IDLE;
                    end
                    default: begin
                        next_state = IDLE;
                    end
                endcase
            end
    
    // 寄存器设定
        
        // 被乘数寄存器
            always@(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    multiplicand_reg <= {WIDTH{1'b0}};
                end
                else if(start)begin
                    multiplicand_reg <= multiplicand;
                end
            end
        
        // 低半区共享移位寄存器pp_low
            always@(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    pp_low <= {WIDTH{1'b0}};
                end
                else if(start)begin
                    pp_low <= multiplier;
                end
                else if(state == WORK)begin
                    pp_low <= {add4_sum, pp_low[WIDTH-1:4]};
                end
            end

        // 存储低位寄存器，保留最低位被移出去的x_i-1
            always@(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    Init0 <= 1'b0;
                end
                else if(start)begin
                    Init0 <= 1'b0;
                end
                else if(state == WORK)begin
                    Init0 <= pp_low[3];
                end
            end
        
        // 4位加法器存储进位寄存器（carry-FF），用于存储上一次的进位输出
            always@(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    carry_FF <= 1'b0;
                end
                else if(start)begin
                    carry_FF <= 1'b0;
                end
                else if(state == WORK)begin
                    carry_FF <= add4_cout;
                end
            end
        
        // 高半区pp_sum寄存器
        // =========================================================================
        // 【硬件难点解析 2：两级有符号 CSA 树的精确符号扩展与右移位宽守恒机制】
        // -------------------------------------------------------------------------
        // 1. 为什么有符号 CSA 不能像无符号 CSA 那样直接丢弃 carry 的最高位？
        //    对于 M 位二进制补码，最高位（第 M-1 位）具有负权重 -2^(M-1)。
        //    当三个 M 位补码送入 CSA 时，最高位全加器满足：x[M-1] + y[M-1] + z[M-1] = sum[M-1] + 2 * carry[M-1]。
        //    乘以负权重 -2^(M-1) 后得到：
        //        -(x[M-1] + y[M-1] + z[M-1]) * 2^(M-1) = -sum[M-1] * 2^(M-1) - carry[M-1] * 2^M
        //    定理结论：在有符号 CSA 中，sum[M-1] 是权重为 -2^(M-1) 的符号位，而 carry[M-1] 则是权重为 -2^M 的新符号位！
        //    因此，若要保证 csa1 输出的补码真值之和 100% 不变（防符号翻转溢出），必须满足：
        //    - 将 M 位的 csa1_sum 符号扩展 1 位至 (M+1) 位：{csa1_sum[M-1], csa1_sum}；
        //    - 将 M 位的 csa1_carry 左移 1 位并完整保留最高位 carry[M-1] 作为第 M 位符号位：{csa1_carry[M-1:0], 1'b0}。
        //
        // 2. 两级 CSA 树的位宽演进账本（设 k = WIDTH）：
        //    - 第 1 级 (csa1，位宽 M = k+4)：
        //      接收 k+4 位的 pp_sum、pp_carry 以及 {z_mult1, {2{extra_dot1}}}，输出 k+4 位的 csa1_sum 和 csa1_carry。
        //    - 第 2 级 (csa2，位宽 M+1 = k+5)：
        //      根据上述定理，为完整保留 csa1_carry[k+3] 符号位，csa2 展宽至 k+5 位：
        //      .x 接符号扩展1位的 {csa1_sum[k+3], csa1_sum} (k+5位)；
        //      .y 接左移1位且填入补偿点的 {csa1_carry, extra_dot1} (k+5位)；
        //      .z 接符号扩展3位的 {{3{z_mult0[k+1]}}, z_mult0} (k+5位)；
        //      最终输出 k+5 位的 csa2_sum[k+4:0] 与 csa2_carry[k+4:0]。
        //
        // 3. 右移 4 位后的位宽自然收缩与守恒（回到 k+4 位寄存器）：
        //    在 WORK 状态末尾执行算术右移 4 位（除以 16）时：
        //    - csa2_sum[k+4:0]：低 4 位 [3:0] 移入 4-bit 加法器；剩余高 k+1 位 [k+4:4] 用其符号位 csa2_sum[k+4]
        //      向上做 3 位符号扩展，即 {{3{csa2_sum[k+4]}}, csa2_sum[k+4:4]}，严丝合缝还原为 k+4 位存入 pp_sum！
        //    - csa2_carry[k+4:0]：因进位天生已左移 1 位（最低位在第1列），仅低 3 位 [2:0] 移入 4-bit 加法器；
        //      剩余高 k+2 位 [k+4:3] 用其符号位 csa2_carry[k+4] 向上做 2 位符号扩展，
        //      即 {{2{csa2_carry[k+4]}}, csa2_carry[k+4:3]}，同样严丝合缝还原为 k+4 位存入 pp_carry！
        // =========================================================================
            always@(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    pp_sum <= {(WIDTH+4){1'b0}};
                end
                else if(start)begin
                    pp_sum <= {(WIDTH+4){1'b0}};
                end
                else if(state == WORK)begin
                    pp_sum <= {{3{csa2_sum[WIDTH+4]}}, csa2_sum[WIDTH+4:4]};
                end
                else if(state == MERGE)begin
                    pp_sum <= adder_sum;
                end
            end
        
        // 高半区pp_carry寄存器
            always@(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    pp_carry <= {(WIDTH+4){1'b0}};
                end
                else if(start||(state == MERGE))begin
                    pp_carry <= {(WIDTH+4){1'b0}};
                end
                else if(state == WORK)begin
                    pp_carry <= {{2{csa2_carry[WIDTH+4]}}, csa2_carry[WIDTH+4:3]};
                end
            end
    
    // Booth recoder & selector；Booth 重编码器和倍数选择器
    // Booth 重编码器与倍数选择器

        booth_recoder_selector #(
            .WIDTH(WIDTH)
        ) booth_low (
            .a(multiplicand_reg),
            .x_triplet({pp_low[1:0], Init0}),
            .z_mult(z_mult0),
            .extra_dot(extra_dot0)
        );

        booth_recoder_selector #(
            .WIDTH(WIDTH)
        ) booth_high (
            .a(multiplicand_reg),
            .x_triplet(pp_low[3:1]),
            .z_mult(z_mult1),
            .extra_dot(extra_dot1)
        );
    
    // CSA: 进位保存加法器
    // =========================================================================
    // 【硬件难点解析 1：双 Booth 负倍数进位补偿 (extra_dot0 与 extra_dot1) 的零成本注入】
    // -------------------------------------------------------------------------
    // 1. 问题背景：
    //    在基-16 双 Booth 架构中，每拍同时产生两个有符号部分积倍数：
    //    - 低位 booth_low 输出：z_mult0 (权重 4^0 = 1) 与进位补偿 extra_dot0 (权重 2^0 = 1，位于第0列)
    //    - 高位 booth_high 输出：z_mult1 (权重 4^1 = 4) 与进位补偿 extra_dot1 (权重 2^2 = 4，位于第2列)
    //    由于右下角的 4-bit 加法器仅有 1 个 cin 端口（且位于第0列），无法直接注入位于第2列的 extra_dot1。
    //
    // 2. 数学等效转换（参见教材 10.3 节 P204 原理）：
    //    高位倍数的真实值 = 4 * (z_mult1 + extra_dot1) = {z_mult1, 2'b00} + 4 * extra_dot1。
    //    利用二进制恒等式：4 * extra_dot1 = 3 * extra_dot1 + extra_dot1 = {2{extra_dot1}} + extra_dot1，
    //    可得：{z_mult1, 2'b00} + 4 * extra_dot1 = {z_mult1, {2{extra_dot1}}} + extra_dot1。
    //    物理意义：将原本左移2位补的 2'b00 替换为 {2{extra_dot1}}（即负倍数取反时低两位0一并取反为 2'b11），
    //    此时若在最低位（第0列）再加 1，会产生向第2列的进位并使低两位归零，从而将 extra_dot1 的权重从第2列降维至第0列！
    //
    // 3. 硬件空槽零成本注入：
    //    转换后，extra_dot1 与 extra_dot0 的权重均为第0列（2^0 = 1），恰好填入电路中第0列的两个天然空槽：
    //    - 空槽 A (csa2 的 .y 端口最低位)：csa1_carry 左移1位对齐权重时，第0列原本补 1'b0，现直接填入 extra_dot1，
    //      构成 .y({csa1_carry, extra_dot1})；
    //    - 空槽 B (add4_inst 的 .cin 端口)：4位小加法器的进位输入端位于第0列，直接接入 .cin(extra_dot0)。
    // =========================================================================
        carry_save_adder #(
            .WIDTH(WIDTH+4)
        ) csa1 (
            .x(pp_sum),
            .y(pp_carry),
            .z({z_mult1, {2{extra_dot1}}}),
            .sum(csa1_sum),
            .carry(csa1_carry)
        );

        carry_save_adder #(
            .WIDTH(WIDTH+5)
        ) csa2 (
            .x({csa1_sum[WIDTH+3], csa1_sum}),
            .y({csa1_carry, extra_dot1}),
            .z({{3{z_mult0[WIDTH+1]}}, z_mult0}),
            .sum(csa2_sum),
            .carry(csa2_carry)
        );
    
    // 4位加法器
        
        k_bit_adder #(
            .WIDTH(4)
        ) add4_inst (
            .x(csa2_sum[3:0]),
            .y({csa2_carry[2:0], carry_FF}),
            .cin(extra_dot0),
            .sum(add4_sum),
            .cout(add4_cout)
        );
    
    // k+4位加法器（MERGE合并加法器）

       k_bit_adder #(
            .WIDTH(WIDTH+4)
        ) add_inst (
            .x(pp_sum),
            .y(pp_carry),
            .cin(carry_FF),
            .sum(adder_sum),
            .cout(adder_cout)
        ); 
    
    // 输出逻辑
        assign done    = (state == DONE);
        assign product = {pp_sum[WIDTH-1:0], pp_low};

endmodule
