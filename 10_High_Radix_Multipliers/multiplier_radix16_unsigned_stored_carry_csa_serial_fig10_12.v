// 本架构参见 Fig 10.12：高半区部分积采用存储进位形式 (Carry-Save) 的无符号基-16 右移乘法器
`include "k_bit_adder_in_10.v"
`include "carry_save_adder_in_10.v"

module multiplier_radix16_unsigned_stored_carry_csa_serial_fig10_12 #(
    parameter WIDTH = 32  // 参数化位宽，默认为 32 位（需为 4 的倍数）
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
            parameter QUARTER_WIDTH = WIDTH / 4; // 每次处理四位乘数时的迭代次数
            parameter CNT_WIDTH = $clog2(QUARTER_WIDTH); // 计数器位宽

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
            
            // 4位加法器存储进位寄存器（carry-FF），用于存储上一次的进位输出
                reg carry_FF; 

        // MUX 信号
            // MUX_a: a倍数生成MUX
                wire [WIDTH+3:0] MUX_a; // 根据x_i选择被乘数或零
            
            // MUX_2a: 2a倍数生成MUX
                wire [WIDTH+3:0] MUX_2a; // 根据x_(i+1)选择被乘数或零

            // MUX_4a: 4a倍数生成MUX
                wire [WIDTH+3:0] MUX_4a; // 根据x_(i+2)选择被乘数或零
                
            // MUX_8a: 8a倍数生成MUX
                wire [WIDTH+3:0] MUX_8a; // 根据x_(i+3)选择被乘数或零
                
        // CSA 信号
                wire [WIDTH+3:0] csa1_left_sum; 
                wire [WIDTH+3:0] csa1_left_carry;
                wire [WIDTH+3:0] csa1_right_sum; 
                wire [WIDTH+3:0] csa1_right_carry; 
                wire [WIDTH+3:0] csa2_sum; 
                wire [WIDTH+3:0] csa2_carry;
                wire [WIDTH+3:0] csa3_sum; 
                wire [WIDTH+3:0] csa3_carry;

        // 4位加法器信号
                wire [3:0] add4_sum; // 4位加法器输出的和
                wire add4_cout; // 4位加法器输出的进位

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
        
        // 高半区pp_sum寄存器
            always@(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    pp_sum <= {WIDTH{1'b0}};
                end
                else if(start)begin
                    pp_sum <= {WIDTH{1'b0}};
                end
                else if(state == WORK)begin
                    pp_sum <= csa3_sum[WIDTH+3:4];
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
                    pp_carry <= csa3_carry[WIDTH+2:3];
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

    // MUX；倍数多路选择器

        // MUX_a: a倍数生成MUX
            assign MUX_a = pp_low[0] ? {4'b0000, multiplicand_reg} : {(WIDTH+4){1'b0}};

        // MUX_2a: 2a倍数生成MUX
            assign MUX_2a = pp_low[1] ? {3'b000, multiplicand_reg, 1'b0} : {(WIDTH+4){1'b0}};

        // MUX_4a: 4a倍数生成MUX
            assign MUX_4a = pp_low[2] ? {2'b00, multiplicand_reg, 2'b00} : {(WIDTH+4){1'b0}};

        // MUX_8a: 8a倍数生成MUX
            assign MUX_8a = pp_low[3] ? {1'b0, multiplicand_reg, 3'b000} : {(WIDTH+4){1'b0}};
    
    // CSA: 进位保存加法器

        carry_save_adder #(
            .WIDTH(WIDTH+4)
        ) csa1_left (
            .x({4'b0000, pp_sum}),
            .y({4'b0000, pp_carry}),
            .z(MUX_8a),
            .sum(csa1_left_sum),
            .carry(csa1_left_carry)
        );

        carry_save_adder #(
            .WIDTH(WIDTH+4)
        ) csa1_right (
            .x(MUX_a),
            .y(MUX_2a),
            .z(MUX_4a),
            .sum(csa1_right_sum),
            .carry(csa1_right_carry)
        );

        carry_save_adder #(
            .WIDTH(WIDTH+4)
        ) csa2 (
            .x(csa1_left_sum),
            .y({csa1_left_carry[WIDTH+2:0], 1'b0}),
            .z(csa1_right_sum),
            .sum(csa2_sum),
            .carry(csa2_carry)
        );

        carry_save_adder #(
            .WIDTH(WIDTH+4)
        ) csa3 (
            .x(csa2_sum),
            .y({csa2_carry[WIDTH+2:0], 1'b0}),
            .z({csa1_right_carry[WIDTH+2:0], 1'b0}),
            .sum(csa3_sum),
            .carry(csa3_carry)
        );

    // 4位加法器
        
        k_bit_adder #(
            .WIDTH(4)
        ) add4_inst (
            .x(csa3_sum[3:0]),
            .y({csa3_carry[2:0], carry_FF}),
            .cin(1'b0),
            .sum(add4_sum),
            .cout(add4_cout)
        );

    // k位加法器（MERGE状态加法器）

        k_bit_adder #(
            .WIDTH(WIDTH)
        ) adder_inst (
            .x(pp_sum),
            .y(pp_carry),
            .cin(carry_FF),
            // 两个无符号k位数相乘的最大值为2^2k-2*(k+1)+1 = (2^k-2)*2^k+1, 
            // 所以其高k位的最大值为2^k-2,故adder_cout为0
            .cout(adder_cout), 
            .sum(adder_sum) 
        );
    
    // 输出逻辑
        assign done    = (state == DONE);
        assign product = {pp_sum, pp_low};

endmodule