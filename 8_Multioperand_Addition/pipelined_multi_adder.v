//本架构参见Fig8.3
`include "adder_4stage.v"

module pipelined_multi_adder #(
    parameter K = 8,  // 输入操作数 x(i) 的位宽
    parameter W = 16  // 最终部分和寄存器的总位宽 (K + log2(n))
)(
    input          clk,
    input          rst_n,
    input  [K-1:0] x_in,
    
    output [W-1:0] final_sum
);

    // 1. 输入延迟级 (Delay 1)
    reg [K-1:0] x_in_d1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) x_in_d1 <= {K{1'b0}};
        else        x_in_d1 <= x_in;
    end

    // 2. Adder A: 合并相邻2个数
    wire [K:0] adder_a_out; // 位宽扩展1位防止溢出
    
    adder_4stage #(
        .IN_A_W (K),
        .IN_B_W (K),
        .OUT_W  (K+1)
    ) u_adder_a (
        .clk    (clk),
        .rst_n  (rst_n),
        .in_a   (x_in_d1), // 延迟1周期的 x(i-1)
        .in_b   (x_in),    // 当前周期的 x(i)
        .out_sum(adder_a_out)
    );

    // 3. 级联延迟级 (Delay 2)
    reg [K:0] adder_a_out_d1;
    reg [K:0] adder_a_out_d2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            adder_a_out_d1 <= {(K+1){1'b0}};
            adder_a_out_d2 <= {(K+1){1'b0}};
        end else begin
            adder_a_out_d1 <= adder_a_out;
            adder_a_out_d2 <= adder_a_out_d1;
        end
    end

    // 4. Adder B: 合并相邻4个数
    wire [K+1:0] adder_b_out; // 位宽再扩展1位
    
    adder_4stage #(
        .IN_A_W (K+1),
        .IN_B_W (K+1),
        .OUT_W  (K+2)
    ) u_adder_b (
        .clk    (clk),
        .rst_n  (rst_n),
        .in_a   (adder_a_out_d2), // 延迟2周期的结果
        .in_b   (adder_a_out),    // 当前周期的结果
        .out_sum(adder_b_out)
    );

    // 5. Adder C: 终极累加器 (带反馈)
    wire [W-1:0] adder_c_out;
    
    adder_4stage #(
        .IN_A_W (K+2),
        .IN_B_W (W),
        .OUT_W  (W)
    ) u_adder_c (
        .clk    (clk),
        .rst_n  (rst_n),
        .in_a   (adder_b_out), 
        .in_b   (adder_c_out), // 反馈环路：直接将输出接回输入
        .out_sum(adder_c_out)
    );

    // 6. 最终输出赋值
    assign final_sum = adder_c_out;

endmodule