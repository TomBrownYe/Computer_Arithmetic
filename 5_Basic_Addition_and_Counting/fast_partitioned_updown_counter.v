//本架构基于Fig5.12
module fast_partitioned_updown_counter #(
    parameter W0 = 2,  // Stage 0 的位宽 (极短，运行在最高频)
    parameter W1 = 6,  // Stage 1 的位宽 (中等)
    parameter W2 = 24  // Stage 2 的位宽 (极长，但计算时间裕量极大)
    //假设每一位加法器的门延迟为Δ，那么为了让系统跑在最高频，时钟周期需满足：
    //Tclk≈W0*Δ
    //事实上，对于W0,W1,W2的选取，并不是任意的，需要满足：
    //W1 ≤ W0 * 2^W0 且 W2 ≤ W0 * 2^(W0 + W1)
    //也就是说，对于W0=2,W1只需要小于8都行，而W2小于2048都可以满足条件
    //这种流水线级别的计数器，其关键路径只取决于W0的计数，非常之短
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire                   en,        // 对应图中的 Increment 脉冲使能
    input  wire                   up_down,   // 计数方向：1 为加法 (Up)，0 为减法 (Down)

    output wire [W2+W1+W0-1 : 0]  count      // 完整计数值输出
);

    // 内部连线预留 (仅作示意)
    wire [W0-1:0] count_s0;
    wire [W1-1:0] count_s1;
    wire [W2-1:0] count_s2;

    wire load_1; // Control 1 给 Stage 1 的握手使能
    wire load_2; // Control 2 给 Stage 2 的握手使能

    assign count = {count_s2, count_s1, count_s0};

    // Stage 0
        wire is_zero_s0 = ~|count_s0;
        wire is_max_s0 = &count_s0;

        // Stage 0 的 Increment/Decrement
        reg [W0-1:0] count_s0_reg;
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)begin
                count_s0_reg <= 0;
            end
            else if(en)begin
                if(up_down)begin
                    count_s0_reg <= count_s0_reg + 1;
                    end
                end
                else begin
                    count_s0_reg <= count_s0_reg - 1;
                    end
                end

        assign count_s0 = count_s0_reg;

    // Control 1
        assign load_1 = en & ((is_max_s0 & up_down) | (is_zero_s0 & ~up_down));
    
    // Stage 1
        wire is_zero_s1 = ~|count_s1;
        wire is_max_s1 = &count_s1;

        // Stage 1 的 Increment/Decrement
        reg [W1-1:0] count_s1_reg;
        //如果在边界上发生了方向折返（即从加法变为减法，或者从减法变为加法），
        //我们不用再重新计算一遍count_s1，而是直接使用上一次的count_s1值作为当前的count_s1值。
        //这需要我们引入一个寄存器来储存旧值，以空间换时间
        reg [W1-1:0] count_s1_shadow;// 影子寄存器：用于保存旧值
        reg last_dir1;// 方向追踪器：记录上一次触发 load_1 时的方向
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)begin
                count_s1_reg <= 0;
                count_s1_shadow <= 0;
                last_dir1 <= 1'b1;
            end
            else if(load_1)begin
                // 方向追踪
                if(up_down != last_dir1)begin
                    count_s1_reg <= count_s1_shadow; // 方向折返，使用旧值
                    last_dir1 <= up_down;            // 更新方向追踪器
                end
                else begin
                    count_s1_shadow <= count_s1_reg; // 保存当前值到影子寄存器
                    last_dir1 <= up_down;            // 更新方向追踪器
                //方向相同时才可启动运算
                // 启动运算
                if(up_down)begin
                    count_s1_reg <= count_s1_reg + 1;
                    end
                else begin
                    count_s1_reg <= count_s1_reg - 1;
                    end
                end
            end
        end

        assign count_s1 = count_s1_reg;

    // Control 2
        assign load_2 = en & ((is_max_s1 & is_max_s0 & up_down)
                            | (is_zero_s1 & is_zero_s0 & ~up_down));

    // Stage 2
        wire is_zero_s2 = ~|count_s2;
        wire is_max_s2 = &count_s2;

        // Stage 2 的 Increment/Decrement
        reg [W2-1:0] count_s2_reg;
        reg [W2-1:0] count_s2_shadow;// 影子寄存器：用于保存旧值
        reg last_dir2;// 方向追踪器：记录上一次触发 load_2 时的方向
        always@(posedge clk or negedge rst_n)begin
            if(!rst_n)begin
                count_s2_reg <= 0;
                count_s2_shadow <= 0;
                last_dir2 <= 1'b1;
            end
            else if(load_2)begin
                // 方向追踪
                if(up_down != last_dir2)begin
                    count_s2_reg <= count_s2_shadow; // 方向折返，使用旧值
                    last_dir2 <= up_down;            // 更新方向追踪器
                end
                else begin
                    count_s2_shadow <= count_s2_reg; // 保存当前值到影子寄存器
                    last_dir2 <= up_down;            // 更新方向追踪器
                //方向相同时才可启动运算
                // 启动运算
                if(up_down)begin
                    count_s2_reg <= count_s2_reg + 1;
                    end
                else begin
                    count_s2_reg <= count_s2_reg - 1;
                    end
                end
            end
        end

        assign count_s2 = count_s2_reg;

endmodule