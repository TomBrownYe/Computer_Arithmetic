//本架构参见Fig7.1
`include "sub_carry_skip_adder.v"

module simple_carry_skip_adder #(
    parameter STAGE = 4, 
    parameter WIDTH = STAGE * 4 //针对数据位宽为4的倍数而言
) (
    input [WIDTH-1:0] x,
    input [WIDTH-1:0] y,
    input             cin,
    output [WIDTH-1:0] sum,
    output            cout
);
    wire [STAGE-1:0] carry_tmp; // 用于连接各个4-bit子模块的进位链
    genvar level;
    generate 
        for(level = 0; level < STAGE; level = level + 1) begin:gen_module
            sub_carry_skip_adder #(.WIDTH(4)) sub_carry_skip_adder_inst(
            .x(x[level*4+3:level*4]),
            .y(y[level*4+3:level*4]),
            .c_in((level == 0) ? cin : carry_tmp[level-1]),
            .sum(sum[level*4+3:level*4])
        );
    end
    endgenerate
endmodule