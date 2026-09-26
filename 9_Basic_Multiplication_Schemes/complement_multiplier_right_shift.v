//本架构参见Fig9.8,为补码乘法器（不带Booth）
`include"k_bit_adder.v"

module complement_multiplier_right_shift #(
    parameter WIDTH = 32 
) (
    input  wire                 clk,        // 系统时钟
    input  wire                 rst_n,      // 异步复位（低电平有效）
    
    // 控制/握手信号
    input  wire                 start,      // 乘法启动信号（脉冲有效,且必须是严格单脉冲）
    output                      done,       // 乘法完成信号（脉冲有效）
    
    // 数据输入
    input  wire [WIDTH-1:0]         multiplicand, // 补码形式被乘数 (a)
    input  wire [WIDTH-1:0]         multiplier,   // 补码形式乘数 (x)
    
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
                    partial_product <= {sum, partial_product[WIDTH-1:1]};
                end
            end

    
    // MUX
        wire Select = (cnt == WIDTH-1); // 直到最后一个周期到达了符号位的时候，才开始判断是加a还是减a（加a的补码）
        wire Enable = partial_product[0]; // 使能即复用寄存器目前残余乘数的最低位，为0时，MUX输出为0
        // 提取部分积的高 WIDTH 位，并进行符号扩展至WIDTH+1位
            wire [WIDTH:0] product_ext ={partial_product[2*WIDTH-1], partial_product[2*WIDTH-1:WIDTH]};
        // 提取被乘数，并进行符号扩展至WIDTH+1位
            wire [WIDTH:0] multiplicand_ext = {multiplicand_reg[WIDTH-1], multiplicand_reg};
        // Select 制MUX
            wire [WIDTH:0] MUX_out = Select ? ~multiplicand_ext : multiplicand_ext;
        // Enable控制MUX，与门控制以节省晶体管面积
            wire [WIDTH:0] sub_add1 = {(WIDTH+1){Enable}} & MUX_out;

    // k位加法器
        wire [WIDTH:0] sum;
        wire [WIDTH:0] sub_add2 = product_ext;

        k_bit_adder #(.WIDTH(WIDTH+1))k_bit_inst(
            .x(sub_add1),
            .y(sub_add2),
            .cin(Select & partial_product[0]), // 在最后一个周期时如果符号位为1，那么要对被乘数取补，此处体现了取反加1的“加1”操作
            .sum(sum),
            .cout()
            // 对于k位补码加法，正确方式是先将加数符号扩展1位，然后接入k+1位加法器，得到的cout丢弃，k+1位的sum为最终和
            // 如果用k位加法器，两个负数相加可能会溢出，sum被截断从而导致结果为正数，进而错误
            // k位加法器的进位输出cout不等同于补码加法和的符号位，比如（-4）+ 6  = 2
            // 1100 + 0110 = 10010， cout = 1，如果考虑cout则结果为-14而非正确的2
            // 如果将这两个数都扩展，11100 + 00110 = 100010， cout = 1，舍弃cout即可得到正确的00010（2）
        );

    // 输出
        assign done = (state == DONE);
        assign product = partial_product; 

endmodule