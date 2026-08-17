//本架构基于Fig5.14与Fig5.15实现
module carry_propagate_adder #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0] x,
    input  wire [WIDTH-1:0] y,
    input  wire             c_in,

    output wire [WIDTH-1:0] sum,
    output wire             c_out
);
//对于CPA，假设其第i位的进位为ci，传播位为pi，产生位为gi，则有：
// ci+1 = gi | （pi & ci）；

wire [WIDTH-1:0] Generate  = x & y;
wire [WIDTH-1:0] Propagate = x ^ y;
wire [WIDTH-2:0] Carry_tmp ;

assign {c_out, Carry_tmp} = Generate | (Propagate & {Carry_tmp,c_in});
assign sum = Propagate ^ {Carry_tmp,c_in};


endmodule