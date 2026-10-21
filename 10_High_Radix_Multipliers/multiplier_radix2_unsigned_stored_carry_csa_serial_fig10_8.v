// 本架构参见 Fig 10.8：高半区部分积采用存储进位形式 (Stored-Carry) 的无符号基-2 右移乘法器
`include "k_bit_adder_in_10.v"
`include "carry_save_adder_in_10.v"

module multiplier_radix2_unsigned_stored_carry_csa_serial_fig10_8 #(
    parameter WIDTH = 32  // 参数化位宽，默认为 32 位
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
            parameter CNT_WIDTH = $clog2(WIDTH); // 计数器位宽

        // 有限状态机状态编码
            parameter IDLE  = 0; // 空闲状态
            parameter WORK  = 1; // 工作状态
            parameter MERGE = 2; // 合并状态（持续1拍，用底部的k位加法器将最后残留的pp_sum和pp_carry合并）
            parameter DONE  = 3; // 完成状态

        // 控制逻辑寄存器
            // 计数器寄存器
                reg [CNT_WIDTH-1:0] cnt; // 计数器

            // 有限状态机寄存器
                reg [1:0] state, next_state; // 当前状态与下一状态

        // 数据寄存器
            // 被乘数寄存器
                reg [WIDTH-1:0] multiplicand_reg; // 锁存的被乘数

            // 高半区pp_sum寄存器
                reg [WIDTH-1:0] pp_sum; // 高半区部分积的和位

            // 高半区pp_carry寄存器
                reg [WIDTH-1:0] pp_carry; // 高半区部分积的进位位

            // 低半区共享移位寄存器pp_low
                reg [WIDTH-1:0] pp_low; // 低半区乘数与移位数据

        // MUX 信号
            // MUX1: 倍数生成MUX
                wire [WIDTH-1:0] MUX_a; // 根据乘数最低位选择被乘数或零

        // CSA 信号
                wire [WIDTH-1:0] csa_sum; // CSA 输出的和
                wire [WIDTH-1:0] csa_carry; // CSA 输出的进位

        // k位加法器信号
                wire [WIDTH-1:0] adder_sum; // k位加法器输出的和
                wire adder_cout; // k位加法器输出的进位

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
                        if(cnt == WIDTH-1) begin
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
        
        // 高半区pp_sum寄存器
            always@(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    pp_sum <= {WIDTH{1'b0}};
                end
                else if(start)begin
                    pp_sum <= {WIDTH{1'b0}};
                end
                else if(state == WORK)begin
                    pp_sum <= {1'b0, csa_sum[WIDTH-1:1]};
                end
                else if(state == MERGE)begin
                    pp_sum <= adder_sum;
                end
            end
        
        // 高半区pp_carry寄存器
            always@(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    pp_carry <= {WIDTH{1'b0}};
                end
                else if(start||(state == MERGE))begin
                    pp_carry <= {WIDTH{1'b0}};
                end
                else if(state == WORK)begin
                    pp_carry <= csa_carry;
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
                    pp_low <= {csa_sum[0], pp_low[WIDTH-1:1]};
                end
            end

    // MUX；倍数多路选择器

        // MUX1: 倍数生成MUX
            assign MUX_a = pp_low[0] ? multiplicand_reg : {WIDTH{1'b0}};
    
    // CSA；进位保存加法器

        carry_save_adder #(
            .WIDTH(WIDTH)
        ) csa_inst (
            .x(pp_sum),
            .y(pp_carry),
            .z(MUX_a),
            .sum(csa_sum),
            .carry(csa_carry)
        );

    // k位加法器

        k_bit_adder #(
            .WIDTH(WIDTH)
        ) adder_inst (
            .x(pp_sum),
            .y(pp_carry),
            .cin(1'b0),
            .cout(adder_cout),
            .sum(adder_sum) // 两个 k 位无符号数乘积高 k 位最大为 2^k - 2，故 adder_cout 恒为 0
        );
    
    // 输出逻辑
        assign done    = (state == DONE);
        assign product = {pp_sum, pp_low};

endmodule
