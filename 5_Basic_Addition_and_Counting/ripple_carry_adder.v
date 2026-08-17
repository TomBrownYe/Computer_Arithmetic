//本架构基于Fig5.3b
module ripple_carry_adder #(
    parameter WIDTH = 32
) (
    input wire [WIDTH-1:0] a,
    input wire [WIDTH-1:0] b,
    input wire cin,
    output wire [WIDTH-1:0] sum,
    output wire cout
);

wire [WIDTH-2:0] carry_tmp;

genvar i;
generate
    for(i = 0; i < WIDTH; i = i + 1) begin: fa_instances
        if(i == 0)begin
            FA fa_inst(
                .a(a[i]),
                .b(b[i]),
                .cin(cin),
                .sum(sum[i]),
                .cout(carry_tmp[i])
            );
        end
        else if(i == WIDTH - 1)begin
            FA fa_inst(
                .a(a[i]),
                .b(b[i]),
                .cin(carry_tmp[i-1]),
                .sum(sum[i]),
                .cout(cout)
            );
        end
        else begin
            FA fa_inst(
                .a(a[i]),
                .b(b[i]),
                .cin(carry_tmp[i-1]),
                .sum(sum[i]),
                .cout(carry_tmp[i])
            );
        end
    end
endgenerate
endmodule

module FA(
    input a,
    input b,
    input cin,

    output sum,
    output cout
);

assign sum = a ^ b ^ cin;
assign cout = (a & b) | (cin & (a ^ b));

endmodule