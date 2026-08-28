//本架构参见Fig7.7
`include"macro_block_cska.v"

module double_level_carry_skip_adder #(
    parameter T = 8 //停下的最终时间戳, T＞2
)(
    x,y,cin,sum,cout
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
            
            //如果当前宏块是第1个宏块，且当前子块是第0个子块，则当前子块位宽减1
            //因为加法器的最右端要强制接收进位Cin，故需要多留空余来处理进位
            if((sub_idx == 0) && (macro_idx == 1))begin
                sub_block_width = sub_block_width - 1;       
            end
        end

        endfunction

    //宏块个数
        localparam N = T - 2;

    //单个宏块的总位宽
        //单个宏块的总位宽为其内部所有子块的位宽累加而得
        function integer macro_block_width;

        input integer macro_idx;
        input integer T;
        
        integer num_sub_blocks;
        integer i;

        begin
            macro_block_width = 0;
            // 调用之前写好的函数，获取当前宏块内有多少个子块
            num_sub_blocks = macro_sub_block_num(macro_idx, T);
            
            // 遍历所有子块（从 0 到 num_sub_blocks - 1）进行位宽累加
            for (i = 0; i < num_sub_blocks; i = i + 1) begin
                macro_block_width = macro_block_width + sub_block_width(i, macro_idx, T);
            end
        end
        endfunction

    //整个加法器的总数据位宽
        //总数据位宽为所有宏块的总位宽累加而得
       function integer get_total_width;

        input integer T;
        
        integer N;
        integer k;
        begin
            get_total_width = 0;
            N = T - 2;
            
            // 遍历所有宏块（注意：你的 macro_idx 是从 1 开始的）
            for (k = 1; k <= N; k = k + 1) begin
                get_total_width = get_total_width + macro_block_width(k, T);
            end
        end
        endfunction 
    //宏块的起始索引
        //每个宏块的起始索引都是之前宏块的位宽累加而得
        function integer macro_start_idx;

        input integer macro_idx;
        input integer T;
        
        integer k;

        begin
            macro_start_idx = 0;
            // 从最右侧的第 1 个宏块，一路累加到当前宏块的前一个 (macro_idx - 1)
            // 注意：当 macro_idx == 1 时，循环条件 k < 1 不成立，完美返回默认值 0
            for (k = 1; k < macro_idx; k = k + 1) begin
                macro_start_idx = macro_start_idx + macro_block_width(k, T);
            end
        end
    endfunction

    //动态计算总数据位宽 WIDTH，并正式声明端口方向与位宽
        localparam WIDTH = get_total_width(T);

        input  wire [WIDTH - 1 : 0] x;
        input  wire [WIDTH - 1 : 0] y;
        input  wire                 cin;
        output wire [WIDTH - 1 : 0] sum;
        output wire                 cout;
    
    //宏块连线

        wire [N:1] carry_macro_tmp; //每个宏块之间的进位连线

        genvar macro_idx;
        generate 
            for(macro_idx = 1; macro_idx <= N; macro_idx = macro_idx + 1) begin:gen_macro_block

                localparam CUR_WIDTH = macro_block_width(macro_idx, T);
                localparam START_IDX = macro_start_idx(macro_idx, T);

                if(macro_idx == 1)begin
                macro_block_cska #(
                    .WIDTH(CUR_WIDTH),
                    .MACRO_IDX(macro_idx),
                    .T(T)
                ) macro_cska_block_inst(
                    .x(x[START_IDX +: CUR_WIDTH]),
                    .y(y[START_IDX +: CUR_WIDTH]),
                    .cin(ci),
                    .sum(sum[START_IDX +: CUR_WIDTH]),
                    .cout(carry_macro_tmp[macro_idx])
                );
                end
                else begin
                macro_block_cska #(
                    .WIDTH(CUR_WIDTH),
                    .MACRO_IDX(macro_idx),
                    .T(T)
                ) macro_cska_block_inst(
                    .x(x[START_IDX +: CUR_WIDTH]),
                    .y(y[START_IDX +: CUR_WIDTH]),
                    .cin(carry_macro_tmp[macro_idx - 1]),
                    .sum(sum[START_IDX +: CUR_WIDTH]),
                    .cout(carry_macro_tmp[macro_idx])
                );
                end
            end
                
        endgenerate

        assign cout = carry_macro_tmp[N];

endmodule
