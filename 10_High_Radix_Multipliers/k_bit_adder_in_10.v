module k_bit_adder #(
    parameter WIDTH = 32 // 加法器数据位宽
)(
    input [WIDTH-1:0] x, // 第一个加数
    input [WIDTH-1:0] y, // 第二个加数
    input             cin, // 输入进位
    output [WIDTH-1:0] sum, // 加法结果
    output             cout // 输出进位
);

    assign {cout,sum} = x + y + cin;

endmodule
