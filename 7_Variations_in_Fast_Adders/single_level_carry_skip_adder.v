//本架构参见Fig7.6
`include"sub_carry_skip_adder.v"

module single_level_carry_skip_adder #(
    parameter T = 8
)(
    x,y,cin,sum,cout
);
    // STAGE 1：利用Verilog编译函数推导各模块位宽与总位宽
    function integer get_block_width;
        input integer t_max;
        input integer idx;
        begin
            if(idx == 0)begin
                get_block_width = 1;// b0 永远为 1，用于吸收全局 cin
            end
            else begin
                // 取产生时间(idx+2)与吸收时间(t_max-idx-1)的最小值
                if ((idx + 2) < (t_max - idx - 1))
                    get_block_width = idx + 2;
                else
                    get_block_width = t_max - idx - 1;
            end
        end
    endfunction

    // STAGE 2：获取第 idx 个模块的起始切片索引
    function integer get_start_idx;
        input integer t_max;
        input integer idx;
        integer i;
        begin
            get_start_idx = 0;
            for (i = 0; i < idx; i = i + 1) begin
                get_start_idx = get_start_idx + get_block_width(t_max, i);
            end
        end
    endfunction

    // STAGE 3：动态计算总数据位宽WIDTH以及模块数量NUM_BLOCKS，并声明端口
    localparam NUM_BLOCKS = T - 1;
    localparam WIDTH = get_start_idx(T, NUM_BLOCKS);// 最后一个模块结束的位置即为总位宽

    //端口定义
    input  wire [WIDTH - 1 : 0] x;
    input  wire [WIDTH - 1 : 0] y;
    input  wire                 cin;
    output wire [WIDTH - 1 : 0] sum;
    output wire                 cout;

    // STAGE 4：实例化各模块，并连接
    wire [NUM_BLOCKS - 1 : 0] internal_carry;
    genvar j;
    generate
        for (j = 0; j < NUM_BLOCKS; j = j + 1) begin : gen_cska_blocks
            
            // 利用函数在编译期静态算出当前模块的位宽和起始位置
            localparam CUR_WIDTH = get_block_width(T, j);
            localparam START_IDX = get_start_idx(T, j);

            if (j == 0) begin : gen_first_block
                // 边界条件：第 0 个块，杜绝出现 j-1
                sub_carry_skip_adder #(
                    .WIDTH(CUR_WIDTH)
                ) sub_cska_inst (
                    .x(x[START_IDX +: CUR_WIDTH]),
                    .y(y[START_IDX +: CUR_WIDTH]),
                    .c_in(cin), // 物理隔离，直接硬连接全局 cin
                    .sum(sum[START_IDX +: CUR_WIDTH]),
                    .c_out(internal_carry[j])
                );
            end
            else begin : gen_other_blocks
                // 常规条件：编译器进入此分支时，j 必定大于等于 1
                sub_carry_skip_adder #(
                    .WIDTH(CUR_WIDTH)
                ) sub_cska_inst (
                    .x(x[START_IDX +: CUR_WIDTH]),
                    .y(y[START_IDX +: CUR_WIDTH]),
                    .c_in(internal_carry[j - 1]), // 此时索引绝对安全
                    .sum(sum[START_IDX +: CUR_WIDTH]),
                    .c_out(internal_carry[j])
                );
            end
        end
    endgenerate

    // 整个链条的最后输出即为全局进位
    assign cout = internal_carry[NUM_BLOCKS - 1];

endmodule

