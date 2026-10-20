//本模块架构为图3.5，通过的门仅为1层异或门与两层与或门，关键路径短，但是并行架构面积较大
module carry_save_adder #(
    parameter WIDTH = 32
)(
    input  wire [WIDTH-1:0] x,
    input  wire [WIDTH-1:0] y,
    input  wire [WIDTH-1:0] z,
    output wire [WIDTH-1:0] sum,
    output wire [WIDTH-1:0] carry
);

assign sum   = x ^ y ^ z;
assign carry = (x & y) | (y & z) | (z & x);
    
endmodule