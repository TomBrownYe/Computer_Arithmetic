module carry_propagate_adder #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0] x,
    input  wire [WIDTH-1:0] y,
    input  wire             c_in,

    output wire [WIDTH-1:0] sum,
    output wire             c_out
);

wire [WIDTH-1:0] Generate  = x & y;
wire [WIDTH-1:0] Propagate = x ^ y;
wire [WIDTH-2:0] Carry_tmp ;

assign {c_out, Carry_tmp} = Generate | (Propagate & {Carry_tmp,c_in});
assign sum = Propagate ^ {Carry_tmp,c_in};


endmodule