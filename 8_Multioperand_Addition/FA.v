`timescale 1ns/1ps

`ifndef DADDA_FA_V
`define DADDA_FA_V

// 一位全加器：将两个本位输入和一个低位进位相加。
module FA (
    input a,
    input b,
    input cin,

    output sum,
    output cout
);
    assign sum = a ^ b ^ cin;
    assign cout = (a & b) | (a & cin) | (b & cin);

endmodule

`endif
