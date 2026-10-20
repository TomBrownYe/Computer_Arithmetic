//本架构参见Fig10.2,基于3a预计算的无符号Radix-4串行右移乘法器
`include"k_bit_adder_in_10.v"

module multiplier_radix4_option1 #(
    parameter WIDTH = 32  // 参数化位宽，默认为 32 位
)(
    input  wire                 clk,        // 系统时钟
    input  wire                 rst_n,      // 异步复位（低电平有效）
    
    // 控制/握手信号
    input  wire                 start,      // 乘法启动信号（脉冲有效,且必须是严格单脉冲）
    output                      done,       // 乘法完成信号（脉冲有效）
    
    // 数据输入
    input  wire [WIDTH-1:0]         multiplicand, // 无符号被乘数 (a)
    input  wire [WIDTH-1:0]         multiplier,   // 无符号乘数 (x)
    
    // 数据输出
    output wire [2*WIDTH-1:0]       product       // 2k位乘积 (p)
);
    
    // 控制逻辑设定
        // 计数器
            parameter HALF_WIDTH = WIDTH / 2;
            parameter CNT_WIDTH = $clog2(HALF_WIDTH); // 计数器位宽
        
            reg [CNT_WIDTH-1:0] cnt; // 计数器
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
            parameter IDLE     = 0; // 空闲状态
            parameter PRE_CALC = 1; // 预计算3a状态（打1拍）
            parameter WORK     = 2; // 工作状态
            parameter DONE     = 3; // 完成状态

            reg[1:0] state, next_state;
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
                        if(cnt == HALF_WIDTH - 1) begin
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
            reg [WIDTH-1:0] multiplicand_reg; 
            always@(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    multiplicand_reg <= {WIDTH{1'b0}};
                end
                else if(start)begin
                    multiplicand_reg <= multiplicand;
                end
            end

        // 共享移位寄存器，高k位存放累加部分积，低k位用于存放未使用的乘数
            reg [2*WIDTH-1:0] partial_product; 
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
        
        // 3a数值寄存器（位宽为 WIDTH+2，在 PRE_CALC 状态锁存加法器结果）
            reg [WIDTH+1:0] reg_3a;
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    reg_3a <= {(WIDTH+2){1'b0}};
                end 
                else if (state == PRE_CALC) begin
                    reg_3a <= sum; // 将 PRE_CALC 周期算出的 a + 2a 锁存进 reg_3a
                end
            end


    
    // MUX
       reg [WIDTH+1:0] mux_4to1_out;
       always@(*)begin
        case(partial_product[1:0])
            2'b00: mux_4to1_out = {(WIDTH+2){1'b0}};              // 0
            2'b01: mux_4to1_out = {2'b00, multiplicand_reg};      // 1a
            2'b10: mux_4to1_out = {1'b0, multiplicand_reg, 1'b0}; // 2a (硬连线左移1位)
            2'b11: mux_4to1_out = reg_3a;                         // 3a (来自预计算寄存器)
            default: mux_4to1_out = {(WIDTH+2){1'b0}};
        endcase
       end

    // k+2位加法器
        wire [WIDTH+1:0] sum;
        wire carry;
        wire [WIDTH+1:0] sub_add1 = (state == PRE_CALC) ? {2'b00, multiplicand_reg} 
                                                        : mux_4to1_out;
        wire [WIDTH+1:0] sub_add2 = (state == PRE_CALC) ? {1'b0, multiplicand_reg, 1'b0} 
                                                        : {2'b00, partial_product[2*WIDTH-1:WIDTH]};

        k_bit_adder #(.WIDTH(WIDTH+2))k_bit_inst(
            .x(sub_add1),
            .y(sub_add2),
            .cin(1'b0),
            .sum(sum),
            .cout(carry) // 由于 (2^k-1) + 3(2^k-1) < 2^(k+2)，此处 carry 恒为 0
        );

    // 输出
        assign done = (state == DONE);
        assign product = partial_product; 

endmodule
               