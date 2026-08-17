//本架构基于Fig5.7 
module provisions_supplement #(
    parameter WIDTH = 32
) (
    input wire [WIDTH-1:0] a,
    input wire [WIDTH-1:0] b,
    input wire cin,

    output wire [WIDTH-1:0] sum,
    output wire cout,
    output wire Overflow,
    output wire Negative,
    output wire Zero
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

assign Overflow = carry_tmp[WIDTH-2] ^ cout;
assign Negative = sum[WIDTH-1];
assign Zero = ~|sum;

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
  