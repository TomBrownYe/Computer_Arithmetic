//本架构参见Fig6.2
module four_bit_lookhead_carry_generator (
    input [3:0] g,
    input [3:0] p,
    input       cin,

    output [3:1] cout,
    output       p_out,
    output       g_out
);

assign cout[1] = g[0] | (cin & p[0]);
assign cout[2] = g[1] | (g[0] & p[1]) | (cin & p[1] & p[0]);
assign cout[3] = g[2] | (g[1] & p[2]) | (g[0] & p[2] & p[1]) | (cin & p[2] & p[1] & p[0]);

assign p_out = p[3] & p[2] & p[1] & p[0];
assign g_out = g[2] | (g[1] & p[2]) | (g[0] & p[2] & p[1]);

endmodule