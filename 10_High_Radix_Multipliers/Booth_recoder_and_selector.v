// 本模块对应 Fig 10.10：用于保留进位或并行乘法的 Booth 重编码与倍数选择子模块,可并行化
module booth_recoder_selector #(
    parameter WIDTH = 32  // 被乘数 a 的位宽 k
)(
    input  wire [WIDTH-1:0]   a,          // k位有符号被乘数 (Multiplicand)
    input  wire [2:0]         x_triplet,  // 3位重叠扫描乘数 {x_{i+1}, x_i, x_{i-1}}
    output wire [WIDTH+1:0]   z_mult,     // (k+2)位倍数输出 z_{i/2} * a (0, a, ~a, 2a, ~2a)
    output wire               extra_dot   // 1位额外点输出 (对应负倍数的 +1 进位补偿)
);
    // Booth Recoder

        // 加/减法控制信号，0代表加，1代表减
        wire neg = (x_triplet == 3'b100) || (x_triplet == 3'b101) || (x_triplet == 3'b110);
        // 非0使能信号，0代表倍数为0，1代表倍数非0
        wire non0 = (x_triplet != 3'b000) && (x_triplet != 3'b111);
        // 2倍幅值选择信号，0代表幅值为1a，1代表幅值为2a
        wire two = (x_triplet == 3'b011) || (x_triplet == 3'b100);
    
    // MUX

        wire Select = two;
        wire Enable = non0;
        wire [WIDTH:0] MUX = Enable ? (Select ? {a, 1'b0} : {a[WIDTH-1], a}) : {(WIDTH+1){1'b0}};
    
    // Selective complement

        assign z_mult = neg ? ~{MUX[WIDTH], MUX} : {MUX[WIDTH], MUX};

    // Extra dot for negative multiples

        assign extra_dot = neg;
    
endmodule
        