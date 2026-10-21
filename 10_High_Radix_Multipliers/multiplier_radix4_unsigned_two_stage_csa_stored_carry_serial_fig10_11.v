// 本架构参见 Fig 10.11：使用两级 CSA 树处理 3a 倍数的无符号基-4 存储进位 (Carry-Save) 右移乘法器
`include "k_bit_adder_in_10.v"
`include "carry_save_adder_in_10.v"

module multiplier_radix4_unsigned_two_stage_csa_stored_carry_serial_fig10_11 #(
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
            
            // 2位加法器存储进位寄存器（carry-FF），用于存储上一次的进位输出
                reg carry_FF; 

        // MUX 信号
            // MUX_a: a倍数生成MUX
                wire [WIDTH+1:0] MUX_a; // 根据x_i选择被乘数或零
            
            // MUX_2a: 2a倍数生成MUX
                wire [WIDTH+1:0] MUX_2a; // 根据x_(i+1)选择被乘数或零
                
        // CSA 信号
                wire [WIDTH+1:0] csa1_sum, csa2_sum; 
                wire [WIDTH+1:0] csa1_carry, csa2_carry;

        // 2位加法器信号
                wire [1:0] add2_sum; // 2位加法器输出的和
                wire add2_cout;      // 2位加法器输出的进位

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
                        if(cnt == HALF_WIDTH-1) begin
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
                    pp_sum <= csa2_sum[WIDTH+1:2];
                end
                else if(state == MERGE)begin
                    pp_sum <= adder_sum[WIDTH-1:0];
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
                    pp_carry <= csa2_carry[WIDTH:1];
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

    // MUX；倍数多路选择器

        // MUX_a: a倍数生成MUX
            assign MUX_a = pp_low[0] ? {2'b00, multiplicand_reg} : {(WIDTH+2){1'b0}};

        // MUX_2a: 2a倍数生成MUX
            assign MUX_2a = pp_low[1] ? {1'b0, multiplicand_reg, 1'b0} : {(WIDTH+2){1'b0}};

    // CSA: 进位保存加法器

        carry_save_adder #(
            .WIDTH(WIDTH+2)
        ) csa1 (
            .x({2'b00, pp_sum}),
            .y(MUX_a),
            .z(MUX_2a),
            .sum(csa1_sum),
            .carry(csa1_carry)
        );

        carry_save_adder #(
            .WIDTH(WIDTH+2)
        ) csa2 (
            .x(csa1_sum),
            .y({csa1_carry[WIDTH:0], 1'b0}),
            .z({2'b00, pp_carry}),
            .sum(csa2_sum),
            .carry(csa2_carry)
        );

    // 2位加法器
        
        k_bit_adder #(
            .WIDTH(2)
        ) add2_inst (
            .x(csa2_sum[1:0]),
            .y({csa2_carry[0], carry_FF}),
            .cin(1'b0),
            .sum(add2_sum),
            .cout(add2_cout)
        );

    // k位加法器（MERGE状态加法器）

        k_bit_adder #(
            .WIDTH(WIDTH)
        ) adder_inst (
            .x(pp_sum),
            .y(pp_carry),
            .cin(carry_FF),
            // 两个无符号k位数相乘的最大值为2^2k-2^(k+1)+1 = (2^k-2)*2^k+1, 
            // 所以其高k位的最大值为2^k-2,故adder_cout为0
            .cout(adder_cout), 
            .sum(adder_sum) 
        );
    
    // 输出逻辑
        assign done    = (state == DONE);
        assign product = {pp_sum, pp_low};

endmodule