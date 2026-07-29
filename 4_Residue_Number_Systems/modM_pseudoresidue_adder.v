//伪余数架构：
//我们不再严格把结果压制在 [0, m-1]，而是允许它充满整个加法器的位宽。
//通过利用加法器的自然溢出和巧妙的补偿，我们可以实现完全不需要比较器和减法器的极速纯前馈加法。

module modM_pseudoresidue_adder #(
    parameter W = 4,
    parameter M = 13
)
(
    input  wire [W-1:0] x,  // Standard Mod-M residue, range [0, M-1]
    input  wire [W-1:0] y,  // Pseudoresidue, range [0, 2^W-1]
    output wire [W-1:0] z   // Pseudoresidue output, range [0, 2^W-1]
);

localparam [W-1:0] K = (1<<W) - M;
//第一级加法（CPA）
wire c_out;
wire [W-1:0] sum_tmp;

assign {c_out, sum_tmp} = x + y;

//构造补偿常数
//如果有溢出，产生的溢出权重是2^W，溢出去除后为了保证余数不变，那么需要补偿2^W-M,也就是K
// 如果 c_out = 1，{W{c_out}} 就是全 1，按位与 K 后得到 K 本身
// 如果 c_out = 0，{W{c_out}} 就是全 0，按位与 K 后得到 0
wire [W-1:0] compensation = {W{c_out}} & K;

//第二级加法（CPA）
assign z = sum_tmp + compensation;

endmodule

