//本架构基于Fig5.11
module async_ripple_counter #(
    parameter WIDTH = 32  // 定义计数器的位宽，一般化为 WIDTH
)(
    // --- 触发输入 (Trigger Input) ---
    input  wire             increment,  // 对应图中的 Increment 脉冲输入

    // --- 异步控制 (Asynchronous Control - 工业标准补充) ---
    input  wire             rst_n,      // 异步复位信号 (低电平有效，用于初始化所有触发器)

    // --- 数据输出 (Data Output) ---
    output wire [WIDTH-1:0] count_out   // 对应图中的 Count output (Q_0 到 Q_{WIDTH-1})
);


    // --- 内部信号 (Internal Signals) ---
    wire [WIDTH-1:0] count;  // 用于连接触发器的输出信号

    // --- 触发器实例化 (Flip-Flop Instantiation) ---
    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : flip_flop_array
            if (i == 0) begin
                // 第一个触发器直接连接到 increment 信号
                t_flip_flop ff (
                    .clk(increment),
                    .rst_n(rst_n),
                    .t(1'b1),  // 取反计数值，实现计数功能
                    .q(count[i])
                );
            end else begin
                // 后续触发器连接到前一个触发器的输出
                t_flip_flop ff (
                    .clk(count[i-1]),
                    .rst_n(rst_n),
                    .t(1'b1),  // 取反计数值，实现计数功能
                    .q(count[i])
                );
            end
        end
    endgenerate

    // 将内部计数信号连接到输出端口
    assign count_out = count;

endmodule

module t_flip_flop (
    input  wire clk,    // 时钟输入
    input  wire rst_n,  // 异步复位输入 (低电平有效)
    input  wire t,      // 数据输入
    output reg  q       // 数据输出
);
    always @(negedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q <= 1'b0;  // 异步复位时将输出清零
        end else begin
            q <= t ? ~q : q;     // 在时钟上升沿采样数据输入
        end
    end

endmodule