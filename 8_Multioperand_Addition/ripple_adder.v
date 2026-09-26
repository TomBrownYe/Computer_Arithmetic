//本模块为tree_multioperand_adder.v的子模块，其架构类似于Fig8.5中每一层level的行波进位加法器
`include"HA.v"
`include"FA.v"

module ripple_adder #(
    parameter W = 32
)(
    input [W-1:0] a,
    input [W-1:0] b,
    
    output [W:0] sum
);

    wire [W:1] c;
    
    genvar i;
    generate
        for(i = 0; i < W; i = i + 1) begin: gen_adder
            if(i == 0) begin
                HA uuu_low(
                    .a(a[i]),
                    .b(b[i]),
                    .sum(sum[i]),
                    .cout(c[i+1])
                );
            end
            else begin
                FA uuu_high(
                    .a(a[i]),
                    .b(b[i]),
                    .cin(c[i]),
                    .sum(sum[i]),
                    .cout(c[i+1])
                );
            end
        end
    endgenerate

    assign sum[W] = c[W];

endmodule