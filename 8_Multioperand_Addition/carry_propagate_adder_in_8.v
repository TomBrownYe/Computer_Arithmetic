//本架构基于Fig5.14与Fig5.15实现
//本模块添加在第八章方便后续使用
`ifndef CARRY_PROPAGATE_ADDER_IN_8_V
`define CARRY_PROPAGATE_ADDER_IN_8_V

module carry_propagate_adder #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0] x,
    input  wire [WIDTH-1:0] y,
    input  wire             c_in,
    output wire [WIDTH-1:0] sum,
    output wire             c_out
);

    // 提前计算全局的 Generate 和 Propagate
    wire [WIDTH-1:0] Generate  = x & y;
    wire [WIDTH-1:0] Propagate = x ^ y;

    // 利用 generate 块处理位宽边界条件
    generate
        if (WIDTH == 1) begin : gen_1bit
            // 当位宽为 1 时，不存在内部进位链 Carry_tmp，直接计算输出
            assign c_out = Generate | (Propagate & c_in);
            assign sum   = Propagate ^ c_in;
        end 
        else begin : gen_multibit
            // 当位宽大于 1 时，声明内部进位链并进行拼接运算
            wire [WIDTH-2:0] Carry_tmp;
            assign {c_out, Carry_tmp} = Generate | (Propagate & {Carry_tmp, c_in});
            assign sum = Propagate ^ {Carry_tmp, c_in};
        end
    endgenerate

endmodule

`endif
