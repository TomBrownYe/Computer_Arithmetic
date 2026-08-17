//本架构基于Fig5.10
module sync_up_down_counter #(
    parameter WIDTH = 32  // 定义计数器的数据位宽，一般化为 WIDTH
)(
    // --- 时钟与全局控制 (Clock & Global Control) ---
    input  wire             clk,            // 对应图中的 Clock
    input  wire             clear,          // 对应图中的 Reset / Clear (清零信号，可根据规范设计为同步或异步)

    // --- 运行控制信号 (Operation Control) ---
    input  wire             enable,         // 对应图中的 Load / Enable (计数器工作使能，高电平有效)
    input  wire             count_b_init,   // 对应图中的 ~Count / Initialize (Mux选择端：0为计数，1为加载 Data in)
    input  wire             up_down,        // 对应增量器上的 1|(-1) (计数方向：1为加1，0为减1)

    // --- 数据接口 (Data Path) ---
    input  wire [WIDTH-1:0] data_in,        // 对应图中的 Data in (并行加载的初始值)
    output reg  [WIDTH-1:0] data_out,       // 对应图中的 Data out (当前计数值)

    // --- 状态标志 (Status Flags) ---
    output wire             overflow        // 对应图中的 Counter overflow / Cout (溢出标志)
);

wire [WIDTH-1:0] count_register_input;
wire [WIDTH-1:0] sum;

//计数/加载 MUX
assign count_register_input = (count_b_init) ? data_in : sum; // Mux选择端：0为计数，1为加载 data_in

//Count register
always@(posedge clk or posedge clear)begin
    if(clear)begin
        data_out <= {WIDTH{1'b0}}; // 清零
    end
    else if(enable)begin
        data_out <= count_register_input; // 计数器工作使能时，更新计数值
    end
end

//incrementer/decrementer
assign {overflow, sum} = (up_down) ? data_out + 1'b1 : data_out - 1'b1; // 根据 up_down 信号选择加1或减1，并输出溢出标志

endmodule