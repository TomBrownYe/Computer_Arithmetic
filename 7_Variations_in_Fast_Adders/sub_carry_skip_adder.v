//本模块为carry skip adder的子模块,其本质就是carry propagate adder
module sub_carry_skip_adder #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0] x,
    input  wire [WIDTH-1:0] y,
    input  wire             c_in,

    output wire [WIDTH-1:0] sum,
    output wire             c_out,
    output wire             p_group
);
    generate
        if (WIDTH == 1) begin : gen_1bit
            // 当位宽为 1 时，直接使用基础全加器逻辑，无需跳跃判断
            wire p = x ^ y;
            wire g = x & y;
            assign sum = p ^ c_in;
            assign c_out = g | (p & c_in);
            assign p_group = p;
        end 
        else begin : gen_multibit
            // 当位宽大于 1 时，保留你原来的完整 CPA + 跳跃逻辑
            wire [WIDTH-2:0] Carry_tmp;
            wire [WIDTH-1:0] Generate  = x & y;
            wire [WIDTH-1:0] Propagate = x ^ y;
            
            wire P_tmp = &Propagate;
            wire c_out_tmp;

            assign {c_out_tmp, Carry_tmp} = Generate | (Propagate & {Carry_tmp, c_in});
            assign sum   = Propagate ^ {Carry_tmp, c_in};
            assign c_out = P_tmp ? c_in : c_out_tmp;
            assign p_group = P_tmp;
        end
    endgenerate

endmodule