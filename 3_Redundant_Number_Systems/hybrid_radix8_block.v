module hybrid_radix8_block (
    // 操作数 X
    input  wire signed [1:0] x_bsd, // X 的最高位 (BSD, 位权 4)
    input  wire        [1:0] x_bin, // X 的低两位 (标准二进制, 位权 2, 1)
    
    // 操作数 Y
    input  wire signed [1:0] y_bsd, // Y 的最高位 (BSD, 位权 4)
    input  wire        [1:0] y_bin, // Y 的低两位 (标准二进制, 位权 2, 1)
    
    // 组间进位链
    input  wire signed [1:0] t_in,  // 从右侧分组传来的传递位 (接入本组的最低位)
    output wire signed [1:0] t_out, // 抛给左侧分组的传递位
    
    // 本组最终结果 S
    output wire signed [1:0] s_bsd, 
    output wire        [1:0] s_bin  
);

    // 请在此处填入你的 RTL 代码
    //为了Fig3.9中的pi与wi对应，代码将分开编写

//pi部分
    //b0 列 (权重 1)：算出 s0 和 c1。
    wire [3:0] p;
    assign p[0] = x_bin[0] ^ y_bin[0];  // 本位停留线
    assign p[1] = x_bin[0] & y_bin[0];  // 溢出中间线 (权重 2)

    // b1 列 (权重 2)：算出 s1 和 c2。
    assign p[2] = x_bin[1] ^ y_bin[1];  // 本位停留线
    assign p[3] = x_bin[1] & y_bin[1];  // 溢出中间线 (权重 4)

    //合并权重2
    wire p_to_2 = p[1] ^ p[2];
    wire p_to_4 = p[1] & p[2];

    //bsd部分
    wire signed [2:0] p_bsd = $signed({x_bsd[1], x_bsd}) + $signed({y_bsd[1], y_bsd});
    wire signed [3:0] p_bsd_total = $signed({p_bsd[2], p_bsd}) + $signed({3'd0, p_to_4}) + $signed({3'd0, p[3]});

    wire signed [5:0] p_total = $signed({p_bsd_total, p_to_2, p[0]});

//t_out与wi部分
    reg signed [5:0] wi;
    reg signed [1:0] t_out_reg;

    always@(*)begin
        if(p_total <= -6'sd4)begin
            t_out_reg = -2'sd1;
            wi = p_total + 6'sd8;
        end
        else if(p_total >= 6'sd5)begin
            t_out_reg = 2'sd1;
            wi = p_total - 6'sd8;
        end
        else begin
            t_out_reg = 2'sd0;
            wi = p_total;
        end
    end

    wire signed [5:0] s =$signed(wi + {{4{t_in[1]}},t_in});

    assign t_out = t_out_reg;
    assign s_bsd = s[3:2];
    assign s_bin = s[1:0];
 
endmodule