module param_radix_to_bin #(
    parameter RADIX      = 10, // 输入的基数 N (默认 10 进制)
    parameter NUM_DIGITS = 4,  // 输入的数位个数 (例如 4 位十进制数)
    parameter DIGIT_W    = 4,  // 单个数位的位宽 (表示 0~9 需要 4 bits)
    parameter OUT_W      = 14  // 输出的总二进制位宽 (9999_10 < 16383，需要 14 bits)
)(
    // 将所有数位拼接在一起输入。
    // 例如十进制 1234，d[3]=1, d[2]=2, d[1]=3, d[0]=4
    // 拼接输入 digits_in = {d3, d2, d1, d0}
    input  wire [NUM_DIGITS*DIGIT_W-1:0] digits_in, 
    
    output wire [OUT_W-1:0]              bin_out
);

reg [OUT_W-1:0] tmp;

always @(*)begin
    tmp = {OUT_W{1'b0}};
    for (integer i = NUM_DIGITS-1; i >= 0; i = i - 1)begin
        tmp = tmp * RADIX + digits_in[i*DIGIT_W +: DIGIT_W];
    end
end

// always @(*)begin
//     tmp = {OUT_W{1'b0}};
//     for (integer i = NUM_DIGITS; i > 0; i = i - 1)begin
//         if(i == NUM_DIGITS)
//         tmp = digits_in[i*DIGIT_W-1 -: DIGIT_W];
//         else
//         tmp = tmp * RADIX + digits_in[i*DIGIT_W -: DIGIT_W];
//     end
// end

assign bin_out = tmp;

endmodule