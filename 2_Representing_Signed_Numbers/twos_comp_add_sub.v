//本模块架构为图2.7，输入数据均为补码形式，正是补码才使得其性能优秀，关键路径短，面积小
//况且相较于原码表示，补码表示的加减法运算更为简单，硬件实现更为容易
module twos_comp_add_sub #(
    parameter WIDTH = 8       
)
(
    input  wire [WIDTH-1:0] x,
    input  wire [WIDTH-1:0] y,
    input wire              sub_add,

    output wire [WIDTH-1:0] result,
    output wire             c_out
);

// Selective Complement 模块
//参与计算的y的实际值，异或门作用是在进行减法时将y取反，进行加法运算
//补码中取反加一的“加一”在Adder模块中通过sub_add信号接入其空闲的c_in端口实现
wire [WIDTH-1:0] y_eff;
assign y_eff = y ^ {WIDTH{sub_add}}; 

// Adder 模块
// 将 sub_add 直接作为进位输入 (c_in)
// 做加法时 (sub_add=0): 结果 = x + y + 0
// 做减法时 (sub_add=1): 结果 = x + ~y + 1 (完美实现 2 的补码的取反加 1)
assign {c_out, result} = x + y_eff + sub_add;

endmodule 