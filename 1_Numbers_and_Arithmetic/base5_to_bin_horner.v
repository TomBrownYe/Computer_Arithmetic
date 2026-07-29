module base5_to_bin_horner (
    input  wire [2:0] d3, // 五进制的最高位 (权重 5^3)
    input  wire [2:0] d2, // 五进制的次高位 (权重 5^2)
    input  wire [2:0] d1, // 五进制的次低位 (权重 5^1)
    input  wire [2:0] d0, // 五进制的最低位 (权重 5^0)
    
    output wire [9:0] bin_out // 转换后的二进制输出 (4444_5 = 624_10，需要 10 bits)
);

wire [11:0] d;
reg [9:0] tmp;

assign d = {d3, d2, d1, d0}; // 将所有数位拼接在一起输入

always @(*)begin
    tmp = {10{1'b0}};

    for (integer i = 3; i >= 0; i = i - 1)begin
        tmp = (tmp << 2) + tmp + d[i*3 +: 3]; // 使用霍纳法则进行基数转换
    end
end

assign bin_out = tmp;

endmodule