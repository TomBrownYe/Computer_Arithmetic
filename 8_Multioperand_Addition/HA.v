`timescale 1ns/1ps

`ifndef DADDA_HA_V
`define DADDA_HA_V

// 一位半加器：将两个本位输入相加，不接收低位进位输入。
module HA (
    input a,
    input b,

    output sum,
    output cout
);

    assign sum = a ^ b;
    assign cout = a & b;

endmodule

`endif
