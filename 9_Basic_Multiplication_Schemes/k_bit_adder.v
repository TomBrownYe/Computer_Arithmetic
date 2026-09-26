module k_bit_adder #(
    parameter WIDTH = 32
)(
    input [WIDTH-1:0] x,
    input [WIDTH-1:0] y,
    input             cin,
    output [WIDTH-1:0] sum,
    output             cout
);

    assign {cout,sum} = x + y + cin;

endmodule 