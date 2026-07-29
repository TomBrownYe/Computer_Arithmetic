//此代码适用于N*A位宽数据，A代表模数2^A-1,N代表总输入数据位宽有N个A，
//与binary_to_mod_encoder.v对应
//对于这种模块，有两个方案：

//方案1：CSA压缩树（Wallace Tree/Dadda Tree）：极致的性能，延迟只有O（logN）
//但要想用纯 generate 语句写出一个能自适应任意N变量的通用华莱士树，代码会极其畸形和庞大。
//对于任意N压缩树，通常不再手写Verilog，
//而是用Python脚本或者Chisel/SpinalHDL等高级硬件生成语言，
//直接按参数“打印”出定死的 Verilog 网表。

//方案2：级联端绕（EAC） 加法树：追求 RTL 通用性
//此时延迟为极高的O（N*A）：采用链式或者二叉树相加：前两个加完，再加第三个，再加第四个...
//但极其适合用原生generate for 循环实现通用化

//方案3：线性CSA压缩阵列
//我们不用像方案1那样写压缩树，也不用像方案2那样为了简便而舍弃延迟
//我们可以采用3：2压缩器，先输入最开始的3片A位片段得到sum和carry
//然后将sum和carry与下一片A位片段进行压缩得到新的sum和carry
//循环往复最后得到最终的sum和carry，再利用CPA与端绕进位得到最终的余数
//这个便是线性保留进位加法器阵列，其是极致的性能（方案1）与代码简便性（方案2）的权衡之下的产物
//该方案延迟为O（N+A）
//方案1的压缩树目前还未学习，方案2与方案3的代码见下：

//本代码采用方案2
module generic_mod_encoder_N_slices1 #(
    parameter N = 8,  // 支持任意 N 个片段相加 (比如 N=8)
    parameter A = 4   // 切片位宽，代表模数 2^A-1 (比如 A=4, 模15)
) (
    input  wire [N*A-1:0] bin_in,   // 总输入位宽 N*A
    output wire [A-1:0]   res_out   // 输出余数位宽 A
);

//定义二维 wire 数组，用于保存每一级的累加结果
wire [A-1:0] stage_sum [N-1:0];

//第 0 级：直接等于输入的最右侧片段
assign stage_sum[0] = bin_in[A-1 : 0];

//Generate 循环生成级联的 EAC 加法器
genvar i;
    generate
        for (i = 1; i < N; i = i + 1) begin : gen_eac_adders
            // 提取当前级要累加的 A 位切片
            wire [A-1:0] current_slice = bin_in[(i+1)*A-1 : i*A];
            
            // 步骤1：执行普通的 A 位加法，并拓宽 1 位以捕获进位 (Cout)
            wire [A:0] raw_sum = stage_sum[i-1] + current_slice;
            
            // 步骤2：端到端进位 (EAC) 绕回。
            // 将溢出的最高位 raw_sum[A] 直接加回低 A 位
            assign stage_sum[i] = raw_sum[A-1:0] + raw_sum[A];
            
            // 架构注：在模 2^A-1 的意义下，两个 <= 2^A-1 的数相加，
            // 绕回后的二次加法绝对不可能产生二次溢出，所以此处是 100% 算术安全的。
        end
    endgenerate

//双重零修正:检查最后的一级的输出 stage_sum[N-1] 是否全为 1,全为1则把结果修正成0。
assign res_out = (stage_sum[N-1] == {A{1'b1}}) ? {A{1'b0}} : stage_sum[N-1];

endmodule

//本代码采用方案3
module generic_mod_encoder_N_slices2 #(
    parameter N = 64,  // 支持任意 N 个片段相加 (比如 N=8)
    parameter A = 4   // 切片位宽，代表模数 2^A-1 (比如 A=4, 模15)
) (
    input  wire [N*A-1:0] bin_in,   // 总输入位宽 N*A
    output wire [A-1:0]   res_out   // 输出余数位宽 A
);

//定义两组二维数组，分别保存每一级的 本位和(sum)与进位(carry)
//其中原始进位每一位权重均是本位和最高位权重
wire [A-1:0] sum   [N-1:2];
wire [A-1:0] carry [N-1:2];

//第0级初始化：
assign sum[2]   = bin_in[A-1:0] ^ bin_in [2*A-1:A] ^ bin_in[3*A-1:2*A];
wire   [A-1:0] raw_carry = bin_in[A-1:0] & bin_in [2*A-1:A] 
                | bin_in [2*A-1:A] & bin_in[3*A-1:2*A] 
                | bin_in[3*A-1:2*A] & bin_in[A-1:0];
                //在generate for循环内部我重复声明了wire [A-1:0] raw_carry
                //如果你在普通的 always 或纯组合逻辑里这么写，
                //编译器会报“变量重复定义”的错误。
                //但在 generate 块并赋予了块名（begin : gen_csa_array）的情况下，
                //编译器会为每一次循环i生成一个独立的作用域。
assign carry[2] = {raw_carry[A-2:0],raw_carry[A-1]};

//generate生成CSA
genvar i ;
generate for(i = 3; i < N; i = i + 1) begin : gen_csa_array
// 提取当前级要累加的 A 位切片
wire [A-1:0] current_slice = bin_in[(i+1)*A-1 : i*A];
 
//计算本位和
assign sum[i] = sum[i-1] ^ carry[i-1] ^ current_slice;

//计算原始进位
wire [A-1:0] raw_carry = (sum[i-1] & carry[i-1]) 
                      | (carry[i-1] & current_slice) 
                      | (current_slice & sum[i-1]);

//计算真正的进位
//模 2^A-1 的灵魂操作：进位左移 1 位，最高位绕回 (EAC),这步操作仅仅是连线交叉，0 逻辑延迟
assign carry[i] = {raw_carry[A-2:0],raw_carry[A-1]};

end
endgenerate

//把所有N个片段压缩完毕后再通过一次CPA
wire [A:0] final_raw_sum = sum[N-1] + carry[N-1];

//别忘了这最后一次 CPA 也会产生进位，需要做端到端绕回 (EAC)
wire [A-1:0] final_eac_sum = final_raw_sum[A-1:0] + final_raw_sum[A];

//双重零修正
assign res_out = (final_eac_sum == {A{1'b1}}) ? {A{1'b0}} : final_eac_sum;

endmodule