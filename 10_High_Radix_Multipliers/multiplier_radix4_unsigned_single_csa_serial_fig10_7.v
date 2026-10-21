// 本架构参见 Fig 10.7,使用 CSA 处理 3a 倍数的无符号基-4 右移乘法器
`include "k_bit_adder_in_10.v"
`include"carry_save_adder_in_10.v"

module multiplier_radix4_unsigned_single_csa_serial_fig10_7 #(
    parameter WIDTH = 32  // 参数化位宽，默认为 32 位（需为偶数）
)(
    input  wire                 clk,          // 系统时钟
    input  wire                 rst_n,        // 异步复位（低电平有效）
    
    // 控制/握手信号
    input  wire                 start,        // 乘法启动信号（严格单脉冲）
    output wire                 done,         // 乘法完成信号（脉冲有效）
    
    // 数据输入
    input  wire [WIDTH-1:0]     multiplicand, // 无符号被乘数 (a)
    input  wire [WIDTH-1:0]     multiplier,   // 无符号乘数 (x)
    
    // 数据输出
    output wire [2*WIDTH-1:0]   product       // 2k位无符号乘积 (p)
);
    // 内部信号
        // 计数器参数
            parameter HALF_WIDTH = WIDTH / 2; // 每次处理两位乘数时的迭代次数
            parameter CNT_WIDTH = $clog2(HALF_WIDTH); // 计数器位宽

        // 有限状态机状态编码
            parameter IDLE = 0; // 空闲状态
            parameter WORK = 1; // 工作状态
            parameter DONE = 2; // 完成状态

        // 控制逻辑寄存器
            // 计数器寄存器
                reg [CNT_WIDTH-1:0] cnt; // 计数器

            // 有限状态机寄存器
                reg [1:0] state, next_state; // 当前状态与下一状态

        // 数据寄存器
            // 被乘数寄存器
                reg [WIDTH-1:0] multiplicand_reg; // 锁存的被乘数

            // 共享移位寄存器
                reg [2*WIDTH-1:0] partial_product; // 高半区累加部分积与低半区未使用乘数

        // MUX 信号
            // MUX_a 输出
                wire [WIDTH+1:0] MUX_a; // 选择被乘数 a 或零

            // MUX_2a 输出
                wire [WIDTH+1:0] MUX_2a; // 选择两倍被乘数 2a 或零

        // 累加乘积旧结果
                wire [WIDTH+1:0] old_pp; // 对齐后的旧部分积

        // CSA 信号
                wire [WIDTH+1:0] csa_sum; // CSA 输出的和
                wire [WIDTH+1:0] csa_carry; // CSA 输出的进位

        // 底部进位传播加法器信号
                wire [WIDTH+1:0] sum; // 底部加法器输出的和
                wire carry; // 底部加法器输出的进位

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
                        if(cnt == HALF_WIDTH-1) begin
                                next_state = DONE;
                        end
                        else begin
                            next_state = WORK;
                        end
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

        // 共享移位寄存器，高k位存放累加部分积，低k位用于存放未使用的乘数
            always@(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    partial_product <= {(2*WIDTH){1'b0}};
                end
                else if(start)begin
                    partial_product <= {{WIDTH{1'b0}}, multiplier};
                end
                else if(state == WORK)begin
                    partial_product <= {sum, partial_product[WIDTH-1:2]};
                end
            end
        
    // MUX；倍数多路选择器
    // 由于三个输入（旧部分积、2a、a）加起来的最大值是(2^k - 1) + 2(2^k - 1) + (2^k - 1) = 4(2^k - 1) < 2^(k+2)，
    // 所以我们将进入 CSA 的三路信号统一对齐为WIDTH + 2位：

        // MUX_a；被乘数选择信号
            assign MUX_a = partial_product[0] ? {2'b00, multiplicand_reg} : {(WIDTH+2){1'b0}};

        // MUX_2a；两倍被乘数选择信号
            assign MUX_2a = partial_product[1] ? {1'b0, multiplicand_reg, 1'b0} : {(WIDTH+2){1'b0}};
        
    // 累加乘积旧结果
        assign old_pp = {2'b00, partial_product[2*WIDTH-1:WIDTH]};
    
    // CSA；进位保存加法器
        // 由于旧部分积、a、2a的和最高不会大于 4(2^k - 1)，不会产生权重为 2^(k+2) 的进位输出，
        // 所以 csa_carry 的最高位 csa_carry[WIDTH+1] 必定为0
        // 这也解释了第151行代码为什么能舍弃掉 csa_carry[WIDTH+1]，
        // 对 csa_carry低WIDTH+1位进行移位来保持位宽为WIDTH+2。
        carry_save_adder #(
            .WIDTH(WIDTH+2)
        ) csa_inst (
            .x(old_pp),
            .y(MUX_a),
            .z(MUX_2a),
            .sum(csa_sum),
            .carry(csa_carry)
        );

    // 底部进位传播加法器
        k_bit_adder #(
            .WIDTH(WIDTH+2)
        ) adder_inst (
            .x(csa_sum),
            .y({csa_carry[WIDTH:0], 1'b0}), 
            .cin(1'b0),
            .sum(sum),
            .cout(carry) // 同样，由于旧部分积、2a、a加起来的最大值不大于4(2^k - 1)< 2^(k+2)，所以carry恒为0；
        );

    // 输出逻辑
    assign done    = (state == DONE);
    assign product = partial_product;
endmodule
