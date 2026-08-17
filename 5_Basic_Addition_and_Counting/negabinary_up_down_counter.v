//本架构出自冗余系统的技术器，具体出自于书中题5.13
module negabinary_up_down_counter #(
    // 定义计数器的位宽
    // 强烈建议将 WIDTH 设为偶数，以完美契合提示中“基数为4”的架构位对齐要求
    parameter WIDTH = 32,
    parameter STAGE = WIDTH / 2  // 定义计数器的阶段数，通常为 WIDTH 的一半  
)(
    // --- 时钟与全局控制 (Clock & Global Control) ---
    input  wire             clk,        // 系统时钟
    input  wire             rst_n,      // 异步复位（低电平有效，用于初始化寄存器为 0）

    // --- 运行控制信号 (Operation Control) ---
    input  wire             en,         // 计数使能信号 (高电平有效)
    input  wire             up_down,    // 计数方向：1 表示加法 (+1)，0 表示减法 (-1)

    // --- 数据输出接口 (Data Output) ---
    output reg  [WIDTH-1:0] count,      // 负二进制计数值输出

    // --- 状态标志 (Status Flags) ---
    output wire             overflow    // 进位/借位溢出标志
);

wire [WIDTH-1:0] next_count;  // 下一计数值的中间信号
wire [1:0] carry [STAGE:0] ;

// --- 初始化进位/借位链 (Carry/Borrow Chain Initialization) ---
assign carry[0] = up_down ? 2'b01 : 2'b11;

genvar i;
generate for (i = 0 ; i < STAGE; i = i + 1)begin : radix_chain

    wire [1:0] current_digit = count[2*i +: 2]; // 当前阶段的两位负二进制数

    negabinary_radix4_unit u_unit (
        .digit_in(current_digit),
        .c_in(carry[i]),
        .digit_out(next_count[2*i +: 2]),
        .c_out(carry[i+1])
    );

end
endgenerate

assign overflow = (carry[STAGE] != 2'b00); // 当最终进位不为 0 时，表示溢出

always@(posedge clk or negedge rst_n)begin
    if (!rst_n)begin
        count <= {WIDTH{1'b0}};
    end
    else if (en)begin
        count <= next_count;
    end
end

endmodule


module negabinary_radix4_unit (
    input  wire [1:0] digit_in,  // 当前阶段的两位负二进制数输入
    input  wire [1:0] c_in,      // 来自前一阶段的进位/借位输入
    output reg  [1:0] digit_out, // 当前阶段的两位负二进制数输出
    output reg  [1:0] c_out      // 当前阶段的进位/借位输出
);

wire [2:0] sum = {1'b0, digit_in} + {1'b0, c_in}; // 计算当前阶段的和，扩展为 3 位以处理进位

always@(*)begin
    //当 digit_in 和 c_in 都为非负数（0或1）时
    if(~digit_in[1] & ~c_in[1])begin
        //只有digit_in与c_in同时为1时，此时和为2，
        //才向上进位，此时向权重多一倍4的高位进1，本位保留-2
        if(sum == 3'b010)begin
            digit_out = 2'b10;
            c_out = 2'b01;
        end
        //其余情况并不进位，sum的末两位即为真实和
        else begin
        digit_out = sum[1:0];
        c_out = 2'b00;
        end
    end
    //当 digit_in 和 c_in 都为负数（-1或-2）时
    else if (digit_in[1] & c_in[1])begin
        //当 sum 为 3'b011 + 3'b010 = 3'b101(为-3）时，
        //此时向上借位，此时向权重多一倍4的高位借1，本位保留1
        if(sum == 3'b101)begin
            digit_out = 2'b01;
            c_out = 2'b11;
        end
        //其余情况并不会借位，sum的末两位即为真实和
        else begin
        digit_out = sum[1:0];
        c_out = 2'b00;
        end
    end
    //当 digit_in 和 c_in 一正一负时
    else begin
        //此时 sum 的范围为 -1 到 1，并不会发生进位或借位
        //直接将 sum 的末两位作为输出
        digit_out = sum[1:0];
        c_out = 2'b00;
    end
    end

endmodule