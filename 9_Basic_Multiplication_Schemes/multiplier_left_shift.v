//本架构参见Fig9.4（a）,无符号左移算法乘法器
`include"k_bit_adder.v"

module multiplier_left_shift #(
    parameter WIDTH = 32  // 参数化位宽，默认为 32 位
)(
    input  wire                 clk,        // 系统时钟
    input  wire                 rst_n,      // 异步复位（低电平有效）
    
    // 控制/握手信号
    input  wire                 start,      // 乘法启动信号（脉冲有效,且必须是严格单脉冲）
    output                      done,       // 乘法完成信号（脉冲有效）
    
    // 数据输入
    input  wire [WIDTH-1:0]         multiplicand, // 被乘数 (a)
    input  wire [WIDTH-1:0]         multiplier,   // 乘数 (x)
    
    // 数据输出
    output wire [2*WIDTH-1:0]       product       // 2k位乘积 (p)
);
    // 控制逻辑设定
        // 计数器
        parameter CNT_WIDTH = $clog2(WIDTH); // 计数器位宽
        
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
            parameter IDLE = 0; // 空闲状态
            parameter WORK = 1; // 工作状态
            parameter DONE = 2; // 完成状态

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
                            next_state = WORK;
                        end
                        else begin
                            next_state = IDLE;
                        end
                    end
                    WORK: begin
                        if(cnt == WIDTH-1) begin
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

        // 共享移位寄存器，高k位存放未使用的乘数，低k位用于存放累加部分积
        reg [2*WIDTH-1:0] partial_product; 
        always@(posedge clk or negedge rst_n) begin
            if(!rst_n) begin
                partial_product <= {(2*WIDTH){1'b0}};
            end
            else if(start)begin
                partial_product <= {multiplier, {WIDTH{1'b0}}};
            end
            else if(state == WORK)begin
                partial_product <= sum;
            end
        end

    
    // MUX
     wire [WIDTH-1:0] sub_add1 = {WIDTH{partial_product[2*WIDTH-1]}} & multiplicand_reg;

    // k位加法器
        wire [2*WIDTH-1:0] sum;
        wire [2*WIDTH-1:0] sub_add2 = {partial_product[2*WIDTH-2:0], 1'b0};

        k_bit_adder #(.WIDTH(2*WIDTH))k_bit_inst(
            .x({{WIDTH{1'b0}}, sub_add1}),
            .y(sub_add2),
            .cin(1'b0),
            .sum(sum),
            .cout()// 左移算法的低位相加不会产生进位，该2k位加法器自然不会产生cout，cout为0，具体证明请见教材的笔记
        );

    // 输出
        assign done = (state == DONE);
        assign product = partial_product; 

endmodule