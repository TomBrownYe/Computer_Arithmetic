//本架构基于Fig5.9
module carry_completion_adder #(
    parameter WIDTH = 32  // 定义加法器的位宽
)(
    // --- 握手与控制接口 (异步电路必备) ---
    input  wire             init,    // 初始化/预充电信号 (Active High)
    output wire             alldone, // 全局进位完成标志信号 (Active High)

    // --- 数据输入接口 ---
    input  wire [WIDTH-1:0] x,       // 操作数 X
    input  wire [WIDTH-1:0] y,       // 操作数 Y
    input  wire             c_in,    // 初始进位输入 (对应图中的 c0)

    // --- 数据输出接口 ---
    output wire [WIDTH-1:0] sum,     // 加法结果和
    output wire             c_out    // 最终进位输出 (对应图中的 ck)
);

wire [WIDTH:0] c; // 进位信号轨 (1表示有进位)
wire [WIDTH:0] b; // 无进位信号轨 (1表示确定无进位)
wire [WIDTH-1:0] d; // 局部完成信号轨 (d_i = b_i | c_i)

genvar i;
generate
    for(i = 0; i < WIDTH; i = i + 1) begin: single_unit_instances
        if(i == 0)begin
            single_unit su_inst(
                .xi(x[i]),
                .yi(y[i]),
                .ci(c_in),
                .bi(~c_in),
                .init(init),
                .si(sum[i]),
                .ci_next(c[i+1]),
                .bi_next(b[i+1]),
                .di_next(d[i])
            );
        end
        else begin
            single_unit su_inst(
                .xi(x[i]),
                .yi(y[i]),
                .ci(c[i]),
                .bi(b[i]),
                .init(init),
                .si(sum[i]),
                .ci_next(c[i+1]),
                .bi_next(b[i+1]),
                .di_next(d[i])
            );
        end
    end
endgenerate

assign c_out = c[WIDTH]; // 最终进位输出
assign alldone = &d; // 全局进位完成标志信号

endmodule

// 单元电路
module single_unit(
    input xi,
    input yi,
    input ci,
    input bi,
    input init,

    output si,
    output ci_next,
    output bi_next,
    output di_next
);

assign si = init ? 1'b0 : (xi ^ yi ^ ci); // 计算当前位的和
assign bi_next = init ? 1'b0 : ((~(xi | yi)) | (bi & ~(xi & yi))); // 计算下一位的无进位信号轨
assign ci_next = init ? 1'b0 : ((xi & yi) | (ci & (xi | yi))); // 计算下一位的进位信号轨
assign di_next = init ? 1'b0 : (bi_next | ci_next); // 计算下一位的局部完成信号轨

endmodule
