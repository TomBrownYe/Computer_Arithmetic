module bsd_limited_carry_slice (
    input  wire signed [1:0] x_i,
    input  wire signed [1:0] y_i,
    input  wire              e_in,   // 来自 i-1 位的预测信号
    input  wire signed [1:0] t_in,  // 来自 i-1 位的传递位

    output wire signed [1:0] s_i,    // 本位最终和
    output wire signed [1:0] t_out,  // 发送给 i+1 位的传递位
    output wire              e_out   // 发送给 i+1 位的预测信号
);

    // 请在此处填入你的 RTL 代码
    // 提示：可以先算出 pi，再根据 e_in 决定拆分规则

    wire signed [2:0] p_i = $signed({x_i[1], x_i} + {y_i[1], y_i}); // 计算 pi
    reg signed [1:0] w_i;// 计算 wi


    // 根据 e_in 决定拆分规则
    reg signed [1:0] t_out_reg;
    always@(*)begin
        case(p_i)
        3'sb010:begin
            t_out_reg = 1;
            w_i = 0;
        end
        3'sb110:begin
            t_out_reg = 1;
            w_i = 0;
        end
        3'sb000:begin
            t_out_reg = 0;
            w_i = 0;
        end
        3'sb100:begin
            t_out_reg = 0;
            w_i = 0;
        end
        3'sb001:begin
            if(e_in)begin
                t_out_reg = 1;
                w_i = -1;
            end
            else begin
                t_out_reg = 0;
                w_i = 1;
            end
        end
        3'sb111:begin
            if(e_in)begin
                t_out_reg = 0;
                w_i = -1;
            end
            else begin
                t_out_reg = -1;
                w_i = 1;
            end
        end
        default:begin
            t_out_reg = 0;
            w_i = 0;
        end
        endcase
    end
    assign t_out = t_out_reg;

    wire signed [2:0] final_sum = $signed({w_i[1], w_i}) + $signed({t_in[1], t_in});
    assign s_i = final_sum[1:0];

    assign e_out = ~p_i[2]; // 根据 pi 的符号位决定 e_out
endmodule