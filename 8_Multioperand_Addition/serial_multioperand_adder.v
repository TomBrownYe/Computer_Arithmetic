//本架构参见Fig8.2
module serial_multioperand_adder #(
    parameter K = 2, //输入操作数的位宽。
    parameter W = 8  //寄存器与输出的总位宽
) (
    input clk,
    input rst_n,
    input valid_in,
    input [K-1:0] data_in,

    output [W-1:0] sum_out

);
    // 定义内部寄存器用于存储累加的部分和
    reg [W-1:0] sum_reg;

    // 时序逻辑：带有异步复位和数据有效使能的累加路径
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sum_reg <= {W{1'b0}}; 
        end else if (valid_in) begin
            // 拼接语法进行零扩展，确保位宽匹配并防止加法溢出丢失
            sum_reg <= sum_reg + {{W-K{1'b0}}, data_in}; 
        end
    end

    // 组合逻辑：将内部寄存器状态直接驱动到输出端口
    assign sum_out = sum_reg;
endmodule 