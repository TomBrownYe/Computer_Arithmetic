//本模块为pipelined_multioperand_adder_4stage的子模块，用于实现4级流水线加法器

module adder_4stage #(
    parameter IN_A_W = 8, // 输入端A位宽
    parameter IN_B_W = 8, // 输入端B位宽
    parameter OUT_W  = 9  // 输出端总和位宽
)(
    input                clk,
    input                rst_n,
    input  [IN_A_W-1:0]  in_a,
    input  [IN_B_W-1:0]  in_b,
    output [OUT_W-1:0]   out_sum
);

    // 4级流水线寄存器
    reg [OUT_W-1:0] stage_q [0:3];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            stage_q[0] <= {OUT_W{1'b0}};
            stage_q[1] <= {OUT_W{1'b0}};
            stage_q[2] <= {OUT_W{1'b0}};
            stage_q[3] <= {OUT_W{1'b0}};
        end else begin
            // 第1级：执行加法（综合工具会自动进行Retiming优化加法器延迟）
            stage_q[0] <= in_a + in_b; 
            // 第2-4级：纯移位打拍延迟
            stage_q[1] <= stage_q[0];
            stage_q[2] <= stage_q[1];
            stage_q[3] <= stage_q[2];
        end
    end

    assign out_sum = stage_q[3];

endmodule