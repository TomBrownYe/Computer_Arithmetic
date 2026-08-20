//本架构参考Fig6.4
`include"four_bit_lookhead_carry_generator.v"

module sixtyfour_bit_lookhead_carry_adder (
    input [63:0] x,
    input [63:0] y,
    input        cin,

    output [63:0] sum,
    output        cout
);

wire [63:0] g = x & y;
wire [63:0] p = x ^ y;

wire [15:0] g_level1;//对应g[0，3]、g[4，7]等
wire [15:0] p_level1;//对应p[0，3]、p[4，7]等
wire [3:0] g_level2;//对应g[0，15]、g[16，31]等
wire [3:0] p_level2;//对应p[0，15]、p[16，31]等
wire       g_level3;//对应g[0，63]
wire       p_level3;//对应p[0，63]
wire [64:0] c;

assign c[0] = cin;

genvar a,b,i;
generate
    //Stage 1: 顶层 Level 3（1个模块）
    //负责吞入 Level 2 的 4个超级组，吐出 c16, c32, c48与g[0，63]、p[0，63]
    four_bit_lookhead_carry_generator u_level3(
        .g(g_level2),
        .p(p_level2),
        .cin(c[0]),
        .cout({c[48],c[32],c[16]}),
        .p_out(p_level3),
        .g_out(g_level3)
    );
    assign c[64] = g_level3 | (p_level3 & c[0]);

    //Stage 2: 中间层 Level 2（4个模块）
    //负责吞入 Level 1 的 16个子组，吐出 c4, c8, c12 与 g[0，15]、g[16，31]、p[0，15]、p[16，31]等
    for(a = 0; a < 4; a = a + 1)begin:gen_level2
        four_bit_lookhead_carry_generator u_level2(
        .g(g_level1[a*4+3 : a*4]),
        .p(p_level1[a*4+3 : a*4]),
        .cin(c[a*16]),
        .cout({c[a*16+12],c[a*16+8],c[a*16+4]}),
        .p_out(p_level2[a]),
        .g_out(g_level2[a])
    );
    end

    //Stage 3: 底层 Level 1 (16 个模块)、
    //负责吞入最原始的64位g和p，吐出c1，c2，c3还有g[0，3]、g[4，7]、p[0，3]、p[4，7]等
    for(b = 0; b < 16; b = b + 1)begin:gen_level3
        four_bit_lookhead_carry_generator u_level3(
        .g(g[b*4+3 : b*4]),
        .p(p[b*4+3 : b*4]),
        .cin(c[b*4]),
        .cout({c[b*4+3],c[b*4+2],c[b*4+1]}),
        .p_out(p_level1[b]),
        .g_out(g_level1[b])
    );
    end

    //Stage 4: 最终求和
    for(i = 0; i < 64; i = i + 1)begin:gen_sum
       assign sum[i] = p[i] ^ c[i];
    end
endgenerate

assign cout = c[64];

endmodule 