//根据课本 4.3 节的理论，将外界的二进制数转换为 RNS 余数时，
//如果选用低成本模数m = 2^a - 1，我们不需要耗费面积去实例化庞大的 ROM 查找表，
//而是可以直接将长二进制数按a位进行切片，然后利用端到端进位加法器将它们相加。


//3WIDTH位宽转换成模2^WIDTH-1的RNS余数,此代码适用范围较小，
//与更为一般的generic_mod_encoder_N_slices.v对应
module binary_to_mod_encoder #(
    parameter WIDTH = 4
)(
    input  wire [3*WIDTH-1:0] bin_in,   // 3*WIDTH-bit unsigned binary input
    output wire [WIDTH-1:0]  res_out   // WIDTH-bit Modulo-2^WIDTH-1 residue output (0 to 2^WIDTH-2 strictly)
);

//Carry Save Adder
wire [WIDTH-1:0] sum_tmp1  = bin_in[3*WIDTH-1:2*WIDTH] ^ 
bin_in[2*WIDTH-1:WIDTH] ^ 
bin_in[WIDTH-1:0];
wire [WIDTH-1:0] cout_tmp1 = (bin_in[3*WIDTH-1:2*WIDTH] & bin_in[2*WIDTH-1:WIDTH]) | 
                  (bin_in[2*WIDTH-1:WIDTH] & bin_in[WIDTH-1:0]) | 
                  (bin_in[WIDTH-1:0] & bin_in[3*WIDTH-1:2*WIDTH]);

//Carry Propagate Adder(31 & 37行代码)
//这里如果担心EDA综合出行波进位，可以例化之前写的carry_propagate_adder.v
wire cout2;
wire [WIDTH-1:0] sum_tmp2;

// 将 CSA 压缩后的两个操作数相加，产生最终进位,
//但这是在模15（2^a-1)下计算余数，根据书中4.3节提到的端绕求模算法，
//进位最高位需要绕回最低位后再相加
assign {cout2,sum_tmp2} = sum_tmp1 + {cout_tmp1[WIDTH-2:0],cout_tmp1[WIDTH-1]};

//同理，这里也需要将最后一次CPA进行端绕进位，但由于2个二进制4位数相加最大的和）为30，
//因此最高位只会在第31行的加法中存在进位，
//在此之后对31行再进行一次端绕加法（也就是37行的代码）并不会再进位
//所以37行是最后的加法，sum_tmp3的位数与sum_tmp2+cout2的位数是一致的，不存在截断
wire [WIDTH-1:0] sum_tmp3 = sum_tmp2 + cout2;

//计算的是模15，如果24行的结果是15则最终余数需要变成0
assign res_out = (sum_tmp3 == {WIDTH{1'b1}}) ? {WIDTH{1'b0}} : sum_tmp3;

endmodule