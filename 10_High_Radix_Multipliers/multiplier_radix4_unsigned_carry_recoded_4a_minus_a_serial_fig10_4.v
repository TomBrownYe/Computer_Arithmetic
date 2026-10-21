//本架构参见Fig10.4,基于串行进位重编码（3a = 4a - a）的无符号Radix-4串行右移乘法器
`include"k_bit_adder_in_10.v"

module multiplier_radix4_unsigned_carry_recoded_4a_minus_a_serial_fig10_4 #(
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
    // 内部信号
        // 控制逻辑设定
            // 计数器
                parameter HALF_WIDTH = WIDTH / 2;
                parameter CNT_WIDTH = $clog2(HALF_WIDTH); // 计数器位宽
                reg [CNT_WIDTH-1:0] cnt; // 计数器

            // 有限状态机
                parameter IDLE      = 0; // 空闲状态
                parameter WORK      = 1; // 工作状态
                parameter EXTRA_ADD = 2; // 末尾进位补偿状态（若最后 carry_next=1 则持续 1 周期）
                parameter DONE      = 3; // 完成状态
                reg [1:0] state;      // 当前状态
                reg [1:0] next_state; // 下一状态

        // 寄存器设定
            // 被乘数寄存器
                reg [WIDTH-1:0] multiplicand_reg; // 被乘数寄存器

            // 共享移位寄存器，最高位为符号保护位，包括其在内的高k+1位存放累加部分积，低k位用于存放未使用的乘数
                reg [2*WIDTH:0] partial_product; // 共享移位寄存器

        // 1位进位触发器，存储上一次加法器的进位输出
            //1-bit Carry FF（存储上一次加法器的进位输出）
                reg carry_FF; // 进位寄存器
                wire carry_next; // 当前加法器产生的下一次进位

        //“+c mod 4”译码器
        //"+c mod 4" decoder；“+c mod 4”译码器
            wire [1:0] x_pair; // 取出乘数的最低两位
            wire [1:0] mux_sel; // 计算 "+c mod 4" 的结果作为 MUX 的选择信号

        // MUX（多路选择器）
        // MUX：四选一倍数多路选择器
            reg [WIDTH+2:0] mux_4to1_out; // 4选1多路选择器输出

        // k+3位加法器
            wire [WIDTH+2:0] sum; // k+3位加法器的和
            wire carry; // k+3位加法器的进位输出
            wire cin_en; // 选择 -a 时加法器的进位输入使能
            wire sign_bit; // 部分积的符号位
            wire [WIDTH+2:0] sub_add1; // k+3位加法器的第一个输入
            wire [WIDTH+2:0] sub_add2; // k+3位加法器的第二个输入

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
                            // 跑完 WIDTH/2 拍后，若还有进位输出则花 1 拍累加，否则直接完成
                            if (carry_next)
                                next_state = EXTRA_ADD;
                            else
                                next_state = DONE;
                        end
                        else begin
                            next_state = WORK;
                        end
                    end
                    EXTRA_ADD: begin
                        next_state = DONE; // 补偿加 1a 只需 1 拍
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

        // 共享移位寄存器，最高位为符号保护位，包括其在内的高k+1位存放累加部分积，低k位用于存放未使用的乘数
            always@(posedge clk or negedge rst_n) begin
                if(!rst_n) begin
                    partial_product <= {(2*WIDTH+1){1'b0}};
                end
                else if(start)begin
                    partial_product <= {{(WIDTH+1){1'b0}}, multiplier};
                end
                else if(state == WORK)begin
                    partial_product <= {sum, partial_product[WIDTH-1:2]};
                end
                else if(state == EXTRA_ADD)begin
                    // EXTRA_ADD 状态：乘数已移完，仅将残留进位 (+1a) 累加回高位，不移位！
                    // 在 EXTRA_ADD 状态下，sum 的最高 3 位 sum[WIDTH+2 : WIDTH] 必定全为 0，
                    // 有效结果只占低 WIDTH 位 sum[WIDTH-1 : 0]
                    partial_product[2*WIDTH:WIDTH] <= sum[WIDTH:0];
                end
            end
        
        // 1位进位触发器，存储上一次加法器的进位输出
        //1-bit Carry FF（存储上一次加法器的进位输出）
            always@(posedge clk or negedge rst_n)begin
                if(!rst_n) begin
                    carry_FF <= 1'b0;
                end
                else if(start)begin
                    carry_FF <= 1'b0;
                end
                else if(state == WORK)begin
                    carry_FF <= carry_next;
                end
            end

    //“+c mod 4”译码器
    //"+c mod 4" decoder；“+c mod 4”译码逻辑
        assign x_pair = partial_product[1:0]; // 取出乘数的最低两位
        // 进位条件：当 x_i+1 与 x_i 同时为1，或 x_i+1 与进位 c 同时为1时置位。
        //进位条件： Set if x_i+1 = x_i = 1, or if x_i+1 = c = 1;
        assign carry_next = (x_pair[1] & x_pair[0]) | (x_pair[1] & carry_FF);
        assign mux_sel = x_pair + carry_FF; // 计算 "+c mod 4" 的结果作为 MUX 的选择信号

    // MUX（多路选择器）
    // MUX；四选一倍数选择逻辑
        always@(*)begin
            case(mux_sel)
                2'b00: mux_4to1_out = {(WIDTH+3){1'b0}};               // 0；选择零倍数
                2'b01: mux_4to1_out = {3'b000, multiplicand_reg};      // 1a；选择一倍被乘数
                2'b10: mux_4to1_out = {2'b00, multiplicand_reg, 1'b0}; // 2a (硬连线左移1位)
                2'b11: mux_4to1_out = ~{3'b000, multiplicand_reg};     // -a (a的按位取反)
                default: mux_4to1_out = {(WIDTH+3){1'b0}};
            endcase
        end


    // k+3位加法器
        assign cin_en = (state == WORK) & (mux_sel == 2'b11); // 当选择-a时，进位输入为1以实现取反加1。

        assign sign_bit = partial_product[2*WIDTH]; // 取出部分积的符号位
        assign sub_add1 = (state == EXTRA_ADD) ? {3'b000, multiplicand_reg} : mux_4to1_out;
        assign sub_add2 = {{2{sign_bit}}, partial_product[2*WIDTH:WIDTH]};

        k_bit_adder #(.WIDTH(WIDTH+3))k_bit_inst(
            .x(sub_add1),
            .y(sub_add2),
            .cin(cin_en),
            .sum(sum),
            .cout(carry) 
            // 这里的carry可能为1，但是补码的进位是算术溢出而非进位输出，
            // 我们已经通过符号保护位将加法器扩展到了（K+3）位，
            // 运算结果的真实数值严格落在(K+3)位补码可表示的范围[-2^{K+2}, 2^{K+2}-1]之内，
            // 永远不会发生有符号算术溢出。
            // 因此，截断丢弃carry后的sum[WIDTH+2:0]本身就已经是完全精确的补码结果。
        );

    // 输出
        assign done = (state == DONE);
        assign product = partial_product[2*WIDTH-1:0]; 

endmodule
