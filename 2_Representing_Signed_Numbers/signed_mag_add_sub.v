//本模块架构为图2.2，输入的数据均为原码（首位是符号位，剩下位置是数值位）形式
//性能差，关键路径过长,而且面积大
module signed_mag_add_sub #(
    parameter WIDTH = 8         // 包含1位符号位和 WIDTH-1 位数值位
)(
    input  wire [WIDTH-1:0] x,
    input  wire [WIDTH-1:0] y,
    input  wire             op, // 控制信号: 0 表示加法 (Add), 1 表示减法 (Sub)
    output wire [WIDTH-1:0] s   // 运算结果
);

//提取符号位与数值位
wire sign_x = x[WIDTH-1];  
wire sign_y = y[WIDTH-1];  
wire [WIDTH-2:0] mag_x = x[WIDTH-2:0];
wire [WIDTH-2:0] mag_y = y[WIDTH-2:0];
wire sign_s;
wire [WIDTH-2:0] mag_s;

//参与计算的y的实际符号
wire sign_y_eff = sign_y ^ op;

//中间接线
wire Compl_x;
wire c_in;
wire Compl_s;
wire c_out;
wire Sign;//c_out已足以去判断s的符号，所以书中引入Sign信号是冗余的

//关于x的Selective complement模块
//与s不同的是，该模块与c_in端口合并在一起才能完成对x取补码的操作
//c_in负责负数补码“取反加一”的“加一”步骤
wire [WIDTH-2:0] pre_x;
assign pre_x = Compl_x ? ~mag_x : mag_x;

//Control模块 
assign Compl_x = (sign_x != sign_y_eff);
assign c_in = (sign_x != sign_y_eff);
assign Compl_s = (sign_x != sign_y_eff) && (c_out == 0);
assign sign_s = (sign_x == sign_y_eff) ? sign_x : (c_out ? sign_y_eff : sign_x);

//Adder模块
wire [WIDTH-2:0] sum_mag;//该代码多余，可注释掉
assign Sign = sum_mag[WIDTH-2];
assign {c_out, sum_mag} = {1'b0, pre_x} + {1'b0, mag_y} + c_in;

//关于s的Selective complement模块
assign mag_s = Compl_s ? ~sum_mag + 1'b1 : sum_mag;

//最终结果
assign s = {sign_s, mag_s};

endmodule