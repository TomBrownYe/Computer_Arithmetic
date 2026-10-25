// 本架构参见 Fig 10.9：例化 Fig 10.10 子模块与 CSA 的有符号基-4 存储进位右移乘法器
`include "k_bit_adder_in_10.v"
`include "carry_save_adder_in_10.v"
`include "radix4_booth_recoder_selector.v"

module multiplier_radix4_signed_booth_stored_carry_csa_serial_fig10_9 #(
    parameter WIDTH = 32  // 参数化位宽，默认为 32 位（需为偶数）
)(
    input  wire                 clk,          // 系统时钟
    input  wire                 rst_n,        // 异步复位（低电平有效）
    input  wire                 start,        // 乘法启动信号（严格单脉冲）
    output wire                 done,         // 乘法完成信号（脉冲有效）
    input  wire [WIDTH-1:0]     multiplicand, // 有符号补码被乘数 (a)
    input  wire [WIDTH-1:0]     multiplier,   // 有符号补码乘数 (x)
    output wire [2*WIDTH-1:0]   product       // 2k位有符号补码乘积 (p)
);
    // 内部信号
        // 控制逻辑设定

            // 计数器
                parameter HALF_WIDTH = WIDTH / 2;
                parameter CNT_WIDTH = $clog2(HALF_WIDTH); // 计数器位宽
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

            // 2位加法器存储进位寄存器（carry-FF），用于存储上一次的进位输出
                reg carry_FF; // 2 位加法器的进位寄存器

            // 高半区pp_sum寄存器
                reg [WIDTH+1:0] pp_sum; // 高半区部分积和寄存器

            // 高半区pp_carry寄存器
                reg [WIDTH+1:0] pp_carry; // 高半区部分积进位寄存器

        // Booth recoder & selector；Booth 重编码器和倍数选择器
        // Booth 重编码器与倍数选择器

            wire [WIDTH+1:0] z_mult; // Booth 选择器输出的部分积
            wire extra_dot; // 负倍数对应的额外进位补偿

        // CSA；进位保存加法器

            wire [WIDTH+1:0] csa_sum, csa_carry; // CSA 输出的和与进位

        // 2位加法器

            wire [1:0] add2_sum; // 2 位加法器的和
            wire add2_cout; // 2 位加法器的进位

        // k+2位合并加法器

            wire [WIDTH+1:0] adder_sum; // k+2位合并加法器的和

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
                            next_state = WORK;
                        end
                        else begin
                            next_state = IDLE;
                        end
                    end
                    WORK: begin
                        if(cnt == HALF_WIDTH-1) begin
                            next_state = MERGE;
                        end
                        else begin
                            next_state = WORK;
                        end
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
                    pp_low <= {add2_sum, pp_low[WIDTH-1:2]};
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
                    Init0 <= pp_low[1];
                end
            end
        
        // 2位加法器存储进位寄存器（carry-FF），用于存储上一次的进位输出
            always@(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    carry_FF <= 1'b0;
                end
                else if(start)begin
                    carry_FF <= 1'b0;
                end
                else if(state == WORK)begin
                    carry_FF <= add2_cout;
                end
            end 
        
        // 高半区pp_sum寄存器
            always@(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    pp_sum <= {(WIDTH+2){1'b0}};
                end
                else if(start)begin
                    pp_sum <= {(WIDTH+2){1'b0}};
                end
                else if(state == WORK)begin
                    pp_sum <= {{2{csa_sum[WIDTH+1]}}, csa_sum[WIDTH+1:2]};
                end
                else if(state == MERGE)begin
                    pp_sum <= adder_sum;
                end
            end
        
        // 高半区pp_carry寄存器
            always@(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    pp_carry <= {(WIDTH+2){1'b0}};
                end
                else if(start||(state == MERGE))begin
                    pp_carry <= {(WIDTH+2){1'b0}};
                end
                else if(state == WORK)begin
                    pp_carry <= {csa_carry[WIDTH+1], csa_carry[WIDTH+1:1]};
                end
            end

    // Booth recoder & selector；Booth 重编码器和倍数选择器
    // Booth 重编码器与倍数选择器

        radix4_booth_recoder_selector #(
            .WIDTH(WIDTH)
        ) booth_recoder_selector_inst (
            .a(multiplicand_reg),
            .x_triplet({pp_low[1:0], Init0}),
            .z_mult(z_mult),
            .extra_dot(extra_dot)
        );

    // CSA；进位保存加法器

        carry_save_adder #(
            .WIDTH(WIDTH+2)
        ) csa_inst (
            .x(pp_sum),
            .y(pp_carry),
            .z(z_mult),
            .sum(csa_sum),
            .carry(csa_carry)
        );

    // 2位加法器

        k_bit_adder #(
            .WIDTH(2)
        ) add2_inst (
            .x(csa_sum[1:0]),
            .y({csa_carry[0], carry_FF}),
            .cin(extra_dot),
            .sum(add2_sum),
            .cout(add2_cout)
        );
    
    // k+2位合并加法器

        k_bit_adder #(
            .WIDTH(WIDTH+2)
        ) adder_inst (
            .x(pp_sum),
            .y(pp_carry),
            .cin(carry_FF),
            .sum(adder_sum),
            .cout()
        );

    // 输出逻辑设定

        assign product = {pp_sum[WIDTH-1:0], pp_low};
        assign done = (state == DONE); 

endmodule
