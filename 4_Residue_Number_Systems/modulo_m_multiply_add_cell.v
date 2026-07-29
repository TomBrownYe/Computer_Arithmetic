//本题架构参见Fig4.4

module modulo_m_multiply_add_cell #(
    parameter h = 16
) (
    input            clk,
    input            rst_n,
    input [h-1:0]    Operand_residue,
    input [h-1:0]    Coefficient_residue,
    input [2*h-1:0]  Sum_in,
    input [h-1:0]    m,

    output [2*h-1:0] Sum_out
    
);

//Multiplier
wire [2*h-1:0] Multiplier_result = Operand_residue * Coefficient_residue;

//Adder
wire [2*h:0] MAC_pre = Multiplier_result + Sum_in;

//Latch模块，流水线寄存器
reg[2*h:0] latched_MAC;
always@(posedge clk or posedge rst_n)begin
    if(!rst_n)
        latched_MAC <= 0;
    else
        latched_MAC <= MAC_pre;
end

//Splitter
wire MSB                 = latched_MAC[2*h];
wire [2*h-1:h] high_LSBs = latched_MAC[2*h-1:h];
wire [h-1:0] low_LSBs    = latched_MAC[h-1:0];

//Mux
wire [h-1:0] adder_compensation = MSB ? ~m + 1'b1 : {h{1'b0}};

//compensation adder
//为了吃掉最高位的溢出，我们假设发生溢出时锁存器值为V=2^2h + U*2^h+L;
//其中U为高h位值，L为低h位值
//在模m的系统中，我们希望把V缩小以能去掉溢出但又不能改变它模m的余数，
//由于m*2^h显然是m的倍数，所以我们从V中减去m*2^h，其模m的值绝对不变,
//还是根据减法规则，加上负数-m等同于加上其补码2^h-m,
//故第二个加法器产生的高h位新值为2^h-m+U,
//拼接上低h位，硬件最终输出总值Vout=（U+2^h-m）*2^h+L
//展开调整后发现Vout=V-m*2^h
//从而得出“去掉溢出位并在高h位加一个-m后余数不变”这一结论
wire [h-1:0] new_high_LSBs = adder_compensation + high_LSBs;

//Sum out
assign Sum_out = {new_high_LSBs, low_LSBs}; 

endmodule 