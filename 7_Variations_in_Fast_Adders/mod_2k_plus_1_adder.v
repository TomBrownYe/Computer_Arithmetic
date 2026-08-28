//本架构为2^K+1的模加法器，具体描述请参见书中例7.3
//减1编码，即4'b0111表示真实数字6，4'b1000表示真实数字7等
//减1编码的加法器，当加数或被加数中有一个为0时，直接输出另一个数
//当两个数都不为0时，先进行加法运算，再进行减1编码的加法运算
module mod_2k_plus_1_adder #(
    parameter K = 4  // 模数为 2^K + 1 (例如 K=4 时，模数为 17)
)(
    input  wire         x_zero,  // 操作数 X 是否为 0 的标志位 (1代表X=0)
    input  wire [K-1:0] x_dim,   // 操作数 X 的减 1 编码 (当 X!=0 时，表示 X-1)
    
    input  wire         y_zero,  // 操作数 Y 是否为 0 的标志位 (1代表Y=0)
    input  wire [K-1:0] y_dim,   // 操作数 Y 的减 1 编码 (当 Y!=0 时，表示 Y-1)
    
    output wire         sum_zero,// 最终和是否为 0 的标志位
    output wire [K-1:0] sum_dim  // 最终和的减 1 编码
);
    wire cout_final, cout_base;
    wire [K-1:0] sum_base, sum_final;

    assign {cout_base, sum_base} = x_dim + y_dim;
    assign {cout_final, sum_final} = sum_base + !cout_base;

    assign sum_zero = ((x_zero && y_zero) || (!x_zero && !y_zero && cout_final)) ? 1'b1 : 1'b0;
    assign sum_dim = (x_zero && !y_zero) ? y_dim : ((!x_zero && y_zero) ? x_dim : sum_final);

endmodule