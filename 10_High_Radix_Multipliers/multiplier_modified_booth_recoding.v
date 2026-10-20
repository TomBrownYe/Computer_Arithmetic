//本架构基于Fig10.6，有符号基-4 改进型Booth串行右移乘法器
//本RTL模块并未体现Fig10.6架构的优越性。对于Fig10.6架构，其优越性在并行化，给出乘数能得到所有的部分积
//事实上，是对于modified booth recoding的编码方式，给出乘数能得到所有的部分积，高度并行化
//得到的所有部分积后可将结果通向加法树中得到最终的结果。

//而本RTL模块是基于串行化的，每个周期乘数寄存器右移两位，给出该周期的乘数，然后再得到对应的部分积

`include"k_bit_adder_in_10.v"

module multiplier_modified_booth_recoding #(
    parameter WIDTH = 32  // 参数化位宽，默认为 32 位
)(
    input  wire                 clk,        // 系统时钟
    input  wire                 rst_n,      // 异步复位（低电平有效）
    
    // 控制/握手信号
    input  wire                 start,      // 乘法启动信号（脉冲有效,且必须是严格单脉冲）
    output                      done,       // 乘法完成信号（脉冲有效）
    
    // 数据输入
    input  wire [WIDTH-1:0]         multiplicand, // 有符号被乘数 (a)
    input  wire [WIDTH-1:0]         multiplier,   //  有符号乘数 (x)
    
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
            wire [WIDTH+1:0] sum;
            wire carry;
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

        // 存储低位寄存器，保留最低位被移出去的x_i-1
            reg Init0;
            always@(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    Init0 <= 1'b0;
                end
                else if(start)begin
                    Init0 <= 1'b0;
                end
                else if(state == WORK)begin
                    Init0 <= partial_product[1];
                end
            end
    
    // Recoding logic

        wire [2:0] x_triplet = {partial_product[1:0], Init0}; // 取出当前的x_i和x_i+1
        // 加/减法控制信号，0代表加，1代表减
        wire neg = (x_triplet == 3'b100) || (x_triplet == 3'b101) || (x_triplet == 3'b110);
        // 非0使能信号，0代表倍数为0，1代表倍数非0
        wire non0 = (x_triplet != 3'b000) && (x_triplet != 3'b111);
        // 2倍幅值选择信号，0代表幅值为1a，1代表幅值为2a
        wire two = (x_triplet == 3'b011) || (x_triplet == 3'b100);

    // MUX

        wire Select = two;
        wire Enable = non0;
        
        wire [WIDTH:0] MUX = Enable ? (Select ? {multiplicand_reg, 1'b0} 
                            : {multiplicand_reg[WIDTH-1], multiplicand_reg}) : {(WIDTH+1){1'b0}};

    // k位加法器

        wire [WIDTH+1:0] sub_add1 = neg ? ~{MUX[WIDTH],MUX} : {MUX[WIDTH],MUX};
        wire [WIDTH+1:0] sub_add2 = {{2{partial_product[2*WIDTH-1]}}, partial_product[2*WIDTH-1:WIDTH]};

        k_bit_adder #(.WIDTH(WIDTH+2))k_bit_inst(
            .x(sub_add1),
            .y(sub_add2),
            .cin(neg),
            .sum(sum),
            .cout(carry)
        );

    // 输出

        assign done = (state == DONE);
        assign product = partial_product; 

endmodule