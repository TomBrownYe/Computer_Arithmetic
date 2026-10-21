// 本模块对应 Fig 10.10：用于保留进位或并行乘法的 Booth 重编码与倍数选择子模块,可并行化
module booth_recoder_selector #(
    parameter WIDTH = 32  // 被乘数 a 的位宽 k
)(
    input  wire [WIDTH-1:0]   a,          // k位有符号被乘数 (Multiplicand)
    input  wire [2:0]         x_triplet,  // 3位重叠扫描乘数 {x_{i+1}, x_i, x_{i-1}}
    output wire [WIDTH+1:0]   z_mult,     // (k+2)位倍数输出 z_{i/2} * a (0, a, ~a, 2a, ~2a)
    output wire               extra_dot   // 1位额外点输出 (对应负倍数的 +1 进位补偿)
);
    // 模块参数
        // Booth 重编码器

            // 加/减法控制信号，0代表加，1代表减
            wire neg;                           // Booth 重编码得到的加/减控制信号
            // 非0使能信号，0代表倍数为0，1代表倍数非0
            wire non0;                          // Booth 重编码得到的非零倍数使能信号
            // 2倍幅值选择信号，0代表幅值为1a，1代表幅值为2a
            wire two;                           // Booth 重编码得到的 1 倍或 2 倍幅值选择信号

        // MUX：倍数多路选择器
        // 倍数多路选择器

            wire Select;                        // MUX 的 1 倍或 2 倍选择信号
            wire Enable;                        // MUX 的非零倍数使能信号
            wire [WIDTH:0] MUX;                 // MUX 输出的被乘数倍数值

    // Booth Recoder；Booth 重编码逻辑
    // Booth 重编码器逻辑

        // 加/减法控制信号，0代表加，1代表减
        assign neg = (x_triplet == 3'b100) || (x_triplet == 3'b101) || (x_triplet == 3'b110);
        // 非0使能信号，0代表倍数为0，1代表倍数非0
        assign non0 = (x_triplet != 3'b000) && (x_triplet != 3'b111);
        // 2倍幅值选择信号，0代表幅值为1a，1代表幅值为2a
        assign two = (x_triplet == 3'b011) || (x_triplet == 3'b100);
    
    // MUX；倍数多路选择逻辑
    // 倍数多路选择器逻辑

        assign Select = two;
        assign Enable = non0;
        assign MUX = Enable ? (Select ? {a, 1'b0} : {a[WIDTH-1], a}) : {(WIDTH+1){1'b0}};
    
    // Selective complement；选择性求补逻辑
    // 选择性求补逻辑

        assign z_mult = neg ? ~{MUX[WIDTH], MUX} : {MUX[WIDTH], MUX};

    // Extra dot for negative multiples；负倍数的额外进位补偿
    // 负倍数的额外进位补偿

        assign extra_dot = neg;

endmodule
        
