//此代码为double_level_carry_skip_adder.v的宏块实现

`include"sub_carry_skip_adder.v"

module macro_block_cska #(
    parameter WIDTH = 8,
    parameter MACRO_IDX = 3,
    parameter T = 8 //最终时间戳，T＞2
) (
    input [WIDTH - 1 : 0] x,
    input [WIDTH - 1 : 0] y,
    input cin,
    output [WIDTH - 1 : 0] sum,
    output cout
);
    //每个宏块内子块个数
        //产生时间极限 β = macro_idx + 2, 吸收时间极限 α = （macro_idx == 1) ? T : (T - macro_idx - 1)
        //macro_idx表示宏块的序号，从右向左从1开始
        //子块个数 γ = min{β-1，α}
        function integer macro_sub_block_num;
        
        input integer macro_idx;
        input integer T;
        
        integer BETA;
        integer ALPHA;

        begin
            BETA = macro_idx + 2;
            ALPHA = ((macro_idx == 1) ? T : (T - macro_idx - 1));

            macro_sub_block_num = ((BETA - 1) < ALPHA) ? (BETA - 1) : ALPHA;                        
        end

        endfunction
    
    //每个子块位宽
        //sub_idx表示子块的序号，从右向左从0开始
        //对于每个宏块内第i个子块（0≤i≤γ-1），其位宽b_i = min{α-i, β-γ+i+1}
        function integer sub_block_width;
        
        input integer sub_idx;
        input integer macro_idx;
        input integer T;

        integer BETA;
        integer ALPHA;
        integer GAMMA; //每个宏块内子块个数，对应上面的macro_sub_block_num

        begin
            BETA = macro_idx + 2;
            ALPHA = ((macro_idx == 1) ? T : (T - macro_idx - 1));
            GAMMA = ((BETA - 1) < ALPHA) ? (BETA - 1) : ALPHA;

            sub_block_width = ((ALPHA - sub_idx) > (BETA - GAMMA + sub_idx + 1))
                              ? (BETA - GAMMA + sub_idx + 1) : (ALPHA - sub_idx);
            if((sub_idx == 0) && (macro_idx == 1))begin
                sub_block_width = sub_block_width - 1;       
            end
        end

        endfunction

    //子块的起始索引
        //每个子块的起始索引都是之前子块的位宽累加而得
        function integer sub_block_start_idx;

        input integer sub_idx;
        input integer macro_idx;
        input integer T;
        
        integer i;

        begin
            sub_block_start_idx = 0;
            // 从局部的第 0 个子块累加到当前子块的前一个 (sub_idx - 1)
            for (i = 0; i < sub_idx; i = i + 1) begin
                sub_block_start_idx = sub_block_start_idx + sub_block_width(i, macro_idx, T);
            end
        end
    endfunction

    //子块个数
        localparam MACRO_SUB_BLOCK_NUM = macro_sub_block_num(MACRO_IDX, T);

    //对每个宏块内部的子块开始连线

        wire [MACRO_SUB_BLOCK_NUM - 1 : 0] carry_sub_tmp;//每个宏块内部的子块之间的进位连线
        wire [MACRO_SUB_BLOCK_NUM - 1 : 0] p_group;//每个宏块内部子块的进位传播信号

        genvar sub_idx; //产生子块序号
        generate 
            for(sub_idx = 0; sub_idx < MACRO_SUB_BLOCK_NUM; sub_idx = sub_idx + 1)begin:gen_sub_block
                
                localparam CUR_WIDTH = sub_block_width(sub_idx, MACRO_IDX, T);
                localparam START_IDX = sub_block_start_idx(sub_idx, MACRO_IDX, T);
                
                if(sub_idx == 0)begin
                    sub_carry_skip_adder #(
                        .WIDTH(CUR_WIDTH)
                    ) sub_cska_block_inst(
                        .x(x[START_IDX +: CUR_WIDTH]),
                        .y(y[START_IDX +: CUR_WIDTH]),
                        .c_in(cin),
                        .sum(sum[START_IDX +: CUR_WIDTH]),
                        .c_out(carry_sub_tmp[sub_idx]),
                        .p_group(p_group[sub_idx])
                    );
                end
                else begin
                    sub_carry_skip_adder #(
                        .WIDTH(CUR_WIDTH)
                    ) sub_cska_block_inst(
                        .x(x[START_IDX +: CUR_WIDTH]),
                        .y(y[START_IDX +: CUR_WIDTH]),
                        .c_in(carry_sub_tmp[sub_idx - 1]),
                        .sum(sum[START_IDX +: CUR_WIDTH]),
                        .c_out(carry_sub_tmp[sub_idx]),
                        .p_group(p_group[sub_idx])
                    );
                end
            end
        endgenerate
        
        assign cout = (&p_group) ? cin : carry_sub_tmp[MACRO_SUB_BLOCK_NUM - 1];

endmodule