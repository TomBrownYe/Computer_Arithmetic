//传统二进制加法器的最大瓶颈是进位链。
//在第 3.5 节中提到，通过引入冗余数字集（如基 2 的带符号位数字），
//可以实现O(1)延迟的无进位加法。

module radix2_sd_adder #(
    parameter WIDTH = 8
) (
    input  wire [2*WIDTH-1:0] A_sd,  // Operand A (2N digits, 2 bits/digit)
    input  wire [2*WIDTH-1:0] B_sd,  // Operand B (2N digits, 2 bits/digit)
    output wire [2*WIDTH-1:0] S_sd   // Sum output (2N digits, 2 bits/digit)
);

wire [2*(WIDTH-1)-1:0] transfer_digits;
wire [1:0] t_out;
wire [2*(WIDTH-1)-1:0] state_transfer;
wire [1:0] state_out;

sd_adder_cell   uuu[WIDTH-1:0](
    A_sd,B_sd,
    {transfer_digits,2'b00},
    {state_transfer,2'b00},
    {t_out,transfer_digits},
    S_sd,
    {state_out,state_transfer});

endmodule

//子模块编写
module sd_adder_cell (
    input   [1:0] a,
    input   [1:0] b,
    input   [1:0] t_in,
    input   [1:0] state_in,

    output  [1:0] t_out,
    output  [1:0] interim_sum,
    output  [1:0] state_out
);

//state信号用来判别传入传输位传进来的是0，1还是-1
assign state_out = {a[1]|b[1], a[0]|b[0]}; 

reg [1:0] sum_tmp;
reg [1:0] t_out_reg;

always@(*)begin
    //a与b均为-1，0，1的情况，
    //传出传输位为a（或b），本位和为0
     if(a == b)begin
         t_out_reg = a;
         sum_tmp   = 2'b00;
     end
     else begin
    //a与b互为相反数情况，
    //传出传输位为0，本位和也为0
        if(a == ~b)begin
            t_out_reg = 2'b00;
            sum_tmp   = 2'b00;
        end
    //a与b其中一个为0另一个为1或者-1的情况
        else begin
            //当a和b其中一个为0另一个为1的情况
            //传出传输位与本位和取决于传入的state低位信号，若state低位信号为1则证明可能有+1进位传入，需要变化，
            //此时传出传输位要变成1，本位和变成-1
            //否则不变
            if(a[0]|b[0])begin
                t_out_reg = (state_in[0]) ? 2'b01: 2'b00;
                sum_tmp   = (state_in[0]) ? 2'b10: 2'b01;
            end
            //当a和b其中一个为0另一个为-1的情况
            //传出传输位与本位和取决于传入的state的高位信号，若state高位信号为1则证明可能有-1进位传入，需要变化，
            //此时传出传输位要变成-1，本位和变成1
            //否则不变
            else begin
            t_out_reg = (state_in[1]) ? 2'b10: 2'b00;
            sum_tmp   = (state_in[1]) ? 2'b01: 2'b10;
            end
        end
     end
end

assign t_out = t_out_reg;
assign interim_sum = (t_in == ~sum_tmp)? 2'b00 : (t_in || sum_tmp);
endmodule
