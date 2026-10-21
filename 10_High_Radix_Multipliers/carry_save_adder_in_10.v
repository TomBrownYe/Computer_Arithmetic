//本模块架构为图3.5，通过的门仅为1层异或门与两层与或门，关键路径短，但是并行架构面积较大
module carry_save_adder #(
    parameter WIDTH = 32 // 输入与输出数据位宽
)(
    input  wire [WIDTH-1:0] x,     // 第一个加数
    input  wire [WIDTH-1:0] y,     // 第二个加数
    input  wire [WIDTH-1:0] z,     // 第三个加数
    output wire [WIDTH-1:0] sum,   // 三个加数的无进位和
    output wire [WIDTH-1:0] carry  // 三个加数产生的进位
);

assign sum   = x ^ y ^ z;
assign carry = (x & y) | (y & z) | (z & x);
    
endmodule
