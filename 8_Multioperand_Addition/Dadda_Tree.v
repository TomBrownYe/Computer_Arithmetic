// 可参数化的 Dadda Tree 多操作数加法器。
//
// data_in 按 data_in[i*K +: K] 的方式展平，第 i 个 K 位无符号操作数位于
// 对应切片中。Dadda 序列和点阵计数在编译展开期计算，生成的数据通路为纯组合逻辑。
//
// sum 和 carry 是压缩结束后剩下的两行等权数据。它们不是已经完成 CPA 的
// 最终整数；外部电路应直接计算 sum + carry 得到所有操作数的最终和。

// 通过文本包含直接引入两个一位压缩单元。
// FA/HA 文件内部带有宏保护，因此本文件既可以单独编译，也可以和 FA.v、HA.v
// 一起出现在同一个 Verilog source list 中而不会重复定义模块。
`include "HA.v"
`include "FA.v"

// 在 include 之后重新声明时间尺度，确保当前模块拥有明确的仿真时间单位，
// 不会从被包含的 FA.v/HA.v 继承 timescale。
`timescale 1ns/1ps

// Verilog 默认允许拼写错误的信号名被隐式创建为 1 位 wire，这类错误很隐蔽。
// 设置为 none 后，任何未显式声明的 net 都会直接触发编译错误，便于 lint 阶段发现。
`default_nettype none

// 本文件末尾会恢复 default_nettype wire，避免影响同一编译单元后续文件的默认规则。

module Dadda_Tree #(
    parameter N = 7,  // 操作数个数
    parameter K = 8   // 每个操作数的位宽
) (
    input  wire [N*K-1:0] data_in,              // N 个 K 位操作数的展平输入
    output wire [K+$clog2(N)-1:0] sum,         // 一路末端压缩行，与 Wallace Tree 接口一致
    output wire [K+$clog2(N)-1:0] carry        // 另一路末端压缩行，与 Wallace Tree 接口一致
);

    // N、K 应为正整数。N <= 2 时保留一个物理旁路层，使末端两行提取保持统一。
    // 注意：这里的 sum/carry 命名是两行接口命名，不表示整行分别只含本位和或进位。
    function automatic integer dadda_level_count;
        input integer max_height;   // 输入点阵的最大初始列高，通常就是 N
        integer height;             // 当前已生成的 Dadda 序列高度
        integer levels;             // 达到 max_height 所需的序列步数
        begin
            height = 2;             // Dadda Tree 的最终目标是两行
            levels = 0;             // 从最终目标向上数，初始没有中间层
            while (height < max_height) begin
                height = (3 * height) / 2; // floor(1.5 * 前一项)
                levels = levels + 1;       // 增加一个实际压缩层
            end
            dadda_level_count = levels;    // 返回实际压缩层数
        end
    endfunction

    // REAL_LEVELS 是按照 N 计算出的真实压缩层数。
    localparam integer REAL_LEVELS = dadda_level_count(N);
    // N=1 或 2 时 REAL_LEVELS 为 0；仍保留一层网格，便于统一生成旁路。
    localparam integer LEVELS = (REAL_LEVELS == 0) ? 1 : REAL_LEVELS;
    // N 个 K 位无符号数的最大和需要 K+ceil(log2(N)) 位。
    localparam integer OUT_WIDTH = K + $clog2(N);
    // 原始 K 个列，加上每层可能传播的进位列，再加一个哨兵列。
    localparam integer COLUMNS = K + LEVELS + 1;
    // 每列最多放 N 个输入点；N<2 时额外保留第二行供末端提取。
    localparam integer ROWS = (N < 2) ? 2 : N;
    // 用于编码列高的位数；COUNT_BITS 也必须覆盖 N 这个最大计数值。
    localparam integer COUNT_BITS = (N < 2) ? 1 : $clog2(N + 1);
    // 计数矩阵的总位数：(层数+初始层) * 列数 * 每个计数的位数。
    localparam integer MATRIX_BITS = (LEVELS + 1) * COLUMNS * COUNT_BITS;

    // 返回指定物理压缩层的目标高度。函数重新生成 Dadda 序列
    // (2、3、4、6、9、...)；整个过程不使用递归调用。
    function automatic integer dadda_target;
        input integer level;         // 物理层编号，0 表示第一个压缩层
        integer index;                // 生成序列时使用的循环变量
        integer height;               // 当前目标高度
        begin
            height = 2;               // 序列从最终两行开始
            if (REAL_LEVELS > 0) begin
                for (index = 0; index < REAL_LEVELS - 1 - level;
                     index = index + 1)
                    height = (3 * height) / 2; // 逐项反向恢复目标高度
            end
            dadda_target = height;    // 返回本层目标列高
        end
    endfunction

    // 每个打包字段记录一个 (层级、列) 位置的点数。这里使用打包的 localparam，
    // 而不是非打包的 localparam 数组，以兼容 Verilog-2001/2005 展开器。
    function automatic [MATRIX_BITS-1:0] make_count_matrix;
        input integer ignored;                 // Verilog-2001 函数需要至少一个输入
        integer counts [0:COLUMNS-1];          // 当前层每一列的点数
        integer next_counts [0:COLUMNS-1];      // 下一层每一列的点数
        integer level;                          // 压缩层循环变量
        integer column;                         // 位列循环变量
        integer target;                         // 当前层 Dadda 目标高度
        integer incoming_carries;              // 前一列送入本列的进位点数
        integer local_limit;                   // 本列还可以保留的本地点数
        integer dots;                           // 当前列输入点数
        integer excess;                         // 超出目标高度的点数
        integer fa_count;                       // 本列需要的 FA 数量
        integer ha_count;                       // 本列需要的 HA 数量
        integer local_outputs;                  // 本列压缩后的本地点数
        begin
            make_count_matrix = {MATRIX_BITS{1'b0}}; // 先将整个矩阵清零

            // 第 0 层：每个原始位列包含所有输入操作数各贡献的一个点；
            // 所有扩展列均显式置为空。
            for (column = 0; column < COLUMNS; column = column + 1) begin
                counts[column] = (column < K) ? N : 0; // 原始列有 N 个点
                make_count_matrix[(column * COUNT_BITS) +: COUNT_BITS] =
                    counts[column];                    // 写入第 0 层计数
            end

            // 在每个压缩层中，第 c 列产生的进位存入下一层的第 c+1 列。
            // 该进位占用第 c+1 列的一个目标高度位置，但不会作为同层计数器的输入。
            // 这样每个 FA/HA 都位于明确的层级边界上，并保持 Dadda Tree 的关键路径深度。
            for (level = 0; level < LEVELS; level = level + 1) begin
                target = dadda_target(level);          // 取本层 Dadda 目标高度
                incoming_carries = 0;                   // 最低位列没有左邻进位

                for (column = 0; column < COLUMNS; column = column + 1)
                    next_counts[column] = 0;            // 清空下一层计数缓存

                for (column = 0; column < COLUMNS; column = column + 1) begin
                    dots = counts[column];              // 取当前列的输入高度
                    local_limit = target - incoming_carries; // 扣除左邻进位占位
                    if (local_limit < 0)
                        local_limit = 0;                 // 防止出现负的保留额度

                    if (dots > local_limit) begin
                        excess = dots - local_limit;     // 只压缩超出的点
                        // 一个 FA 可消除两个本列点；只有当剩余超出量为奇数、
                        // 需要消除最后一个点时才使用 HA。
                        fa_count = excess / 2;            // 每个 FA 减少 2 个点
                        ha_count = excess % 2;            // 奇数余量用 1 个 HA
                    end
                    else begin
                        fa_count = 0;                     // 未超高，不例化 FA
                        ha_count = 0;                     // 未超高，不例化 HA
                    end

                    local_outputs = dots - (2 * fa_count) - ha_count; // 本列剩余点
                    next_counts[column] = incoming_carries + local_outputs;
                    // 本列 FA/HA 的 cout 将成为下一列的 incoming_carries。
                    incoming_carries = fa_count + ha_count;
                end

                for (column = 0; column < COLUMNS; column = column + 1) begin
                    counts[column] = next_counts[column]; // 推进到下一层
                    make_count_matrix[((level + 1) * COLUMNS + column) *
                                      COUNT_BITS +: COUNT_BITS] = counts[column];
                end
            end
        end
    endfunction

    localparam [MATRIX_BITS-1:0] COUNT_MATRIX = make_count_matrix(0);

    // 从打包的 COUNT_MATRIX 中读取指定层级、指定列的点数。
    function automatic integer matrix_count;
        input integer level;       // 层级编号，0 表示输入层
        input integer column;      // 位列编号，0 表示最低有效位列
        begin
            matrix_count = COUNT_MATRIX[((level * COLUMNS + column) *
                                         COUNT_BITS) +: COUNT_BITS];
        end
    endfunction

    // 重新计算某个生成单元从前一列接收到的进位点数。
    // 这是编译展开期循环，不是递归函数，也不会生成硬件循环。
    function automatic integer carry_into_column;
        input integer level;                 // 要查询的压缩层
        input integer stop_column;            // 目标列，计算其左侧所有列
        integer column;                       // 左到右扫描变量
        integer target;                       // 本层目标高度
        integer incoming_carries;             // 扫描到当前列时的进位数
        integer local_limit;                  // 扣除进位后的本地额度
        integer dots;                         // 当前被扫描列的点数
        integer excess;                       // 当前列超出的点数
        integer fa_count;                     // 当前列 FA 数量
        integer ha_count;                     // 当前列 HA 数量
        begin
            target = dadda_target(level);     // 得到该层的目标高度
            incoming_carries = 0;             // 第 0 列没有左邻进位

            for (column = 0; column < stop_column; column = column + 1) begin
                dots = matrix_count(level, column); // 读取扫描列高度
                local_limit = target - incoming_carries;
                if (local_limit < 0)
                    local_limit = 0;

                if (dots > local_limit) begin
                    excess = dots - local_limit;      // 只针对超出的部分压缩
                    fa_count = excess / 2;             // 一个 FA 消掉两个点
                    ha_count = excess % 2;             // 一个 HA 消掉一个点
                    incoming_carries = fa_count + ha_count; // 传给下一列
                end
                else begin
                    incoming_carries = 0;              // 本列无压缩器、无新进位
                end
            end

            carry_into_column = incoming_carries;       // 返回目标列的输入进位数
        end
    endfunction

    // 为什么没有直接例化 carry_save_adder：
    // carry_save_adder_in_8.v 是规则的向量级三输入压缩器，carry 端口仍处在
    // 与 sum 相同的 bit 下标中；而 Dadda Tree 的每一列高度不规则，FA/HA 的
    // cout 必须逐点跨到“下一列”的下一层。直接连接一个向量 CSA 无法表达这种
    // 跨列路由，也无法在每列只压缩必要点数。因此这里使用一位 FA/HA；它们本身
    // 正是 Dadda 点阵所需的 3:2、2:2 压缩单元，综合后同样可以映射为 CSA 单元。

    // wire_grid[level*COLUMNS + column][row] 是三维 (层级、列、行) 点阵的
    // 可移植扁平化表示。unpacked 下标编码 (level,column)，packed bit 下标编码 row。
    wire [ROWS-1:0] wire_grid [0:(LEVELS + 1)*COLUMNS-1];

    // 第 0 层输入点阵；所有未使用的输入网格节点都显式接零。
    genvar init_column; // 输入层的列生成变量
    genvar init_row;    // 输入层的行生成变量
    generate
        for (init_column = 0; init_column < COLUMNS;
             init_column = init_column + 1) begin: gen_initial_column
            for (init_row = 0; init_row < ROWS;
                 init_row = init_row + 1) begin: gen_initial_row
                if ((init_column < K) && (init_row < N)) begin: gen_input_dot
                    // 第 init_row 个操作数的第 init_column 位，成为该列的一个点。
                    assign wire_grid[init_column][init_row] =
                        data_in[init_row*K + init_column];
                end
                else begin: gen_input_tieoff
                    // 高位扩展列和多余行没有真实输入，必须显式接 0。
                    assign wire_grid[init_column][init_row] = 1'b0;
                end
            end
        end
    endgenerate

    // Dadda 计数器与旁路织网。下一层的每个点恰好只有一个驱动源：
    // 前一列进位、本列计数器 sum、旁路信号，或下方的专用接零线。
    genvar level_index;   // 压缩层生成变量
    genvar column_index;  // 位列生成变量
    genvar fa_index;      // 当前列内 FA 编号
    genvar bypass_index;  // 当前列内旁路点编号
    genvar tie_row;       // 目标列接零行编号
    generate
        for (level_index = 0; level_index < LEVELS;
             level_index = level_index + 1) begin: gen_dadda_level
            for (column_index = 0; column_index < COLUMNS;
                 column_index = column_index + 1) begin: gen_dadda_column
                // 以下 localparam 都是编译展开期常量，不会综合成寄存器或逻辑。
                localparam integer DOTS = matrix_count(level_index, column_index);
                // DOTS：本层开始时，本列包含的输入点数量。
                localparam integer TARGET = dadda_target(level_index);
                // TARGET：本压缩层允许的最大列高。
                localparam integer INCOMING_CARRIES =
                    carry_into_column(level_index, column_index);
                // INCOMING_CARRIES：前一列压缩器送到本列的进位点数量。
                localparam integer LOCAL_LIMIT =
                    (TARGET > INCOMING_CARRIES) ?
                    (TARGET - INCOMING_CARRIES) : 0;
                // LOCAL_LIMIT：扣除进位占位后，本列本地输入允许保留的点数。
                localparam integer EXCESS =
                    (DOTS > LOCAL_LIMIT) ? (DOTS - LOCAL_LIMIT) : 0;
                // EXCESS：需要通过 FA/HA 删除的超额点数。
                localparam integer FA_COUNT = EXCESS / 2;
                // 每个 FA 将 3 个输入点变为 1 个 sum 点和 1 个 carry 点，
                // 因而本列点数净减少 2 个。
                localparam integer HA_COUNT = EXCESS % 2;
                // 当超额为奇数时，最后剩余 1 个点由 HA 消除。
                localparam integer BYPASS_COUNT =
                    DOTS - (3 * FA_COUNT) - (2 * HA_COUNT);
                // BYPASS_COUNT：既没有送入压缩器、也没有被前一列占用的旁路点。
                localparam integer NEXT_DOTS =
                    matrix_count(level_index + 1, column_index);
                // NEXT_DOTS：矩阵函数计算出的下一层目标列高，用于接零。

                // 最后的扩展列没有有意义的进位来源。COLUMNS 多保留了一列，
                // 因而该列无需计数器；条件判断同时避免越界引用网线。
                if (column_index < COLUMNS - 1) begin: gen_counter_column
                    for (fa_index = 0; fa_index < FA_COUNT;
                         fa_index = fa_index + 1) begin: gen_fa
                        // 当前列每 3 个输入点实例化一个 FA。
                        // sum 留在当前列的下一层，cout 跨到下一列的下一层。
                        FA u_fa (
                            .a   (wire_grid[level_index*COLUMNS + column_index]
                                  [3*fa_index]),
                            .b   (wire_grid[level_index*COLUMNS + column_index]
                                  [3*fa_index + 1]),
                            .cin (wire_grid[level_index*COLUMNS + column_index]
                                  [3*fa_index + 2]),
                            .sum (wire_grid[(level_index + 1)*COLUMNS +
                                            column_index]
                                  [INCOMING_CARRIES + fa_index]),
                            .cout(wire_grid[(level_index + 1)*COLUMNS +
                                             column_index + 1][fa_index])
                        );
                    end

                    if (HA_COUNT != 0) begin: gen_ha
                        // 超额为奇数时实例化一个 HA，连接方式与 FA 相同，
                        // 但 HA 只有两个本地输入，没有 cin。
                        HA u_ha (
                            .a   (wire_grid[level_index*COLUMNS + column_index]
                                  [3*FA_COUNT]),
                            .b   (wire_grid[level_index*COLUMNS + column_index]
                                  [3*FA_COUNT + 1]),
                            .sum (wire_grid[(level_index + 1)*COLUMNS +
                                            column_index]
                                  [INCOMING_CARRIES + FA_COUNT]),
                            .cout(wire_grid[(level_index + 1)*COLUMNS +
                                             column_index + 1][FA_COUNT])
                        );
                    end
                end

                // 未被计数器消耗的点保持原列位置，并排在输入进位和本地计数器
                // sum 之后传递到下一层。
                for (bypass_index = 0; bypass_index < BYPASS_COUNT;
                     bypass_index = bypass_index + 1) begin: gen_bypass
                    // 未压缩的输入点直接移动到下一层同一列，保持其权重不变。
                    assign wire_grid[(level_index + 1)*COLUMNS + column_index]
                           [INCOMING_CARRIES + FA_COUNT + HA_COUNT +
                            bypass_index] =
                        wire_grid[level_index*COLUMNS + column_index]
                                 [3*FA_COUNT + 2*HA_COUNT + bypass_index];
                end

                // 目标列中所有未使用的点都显式接地。结合第 0 层的接零线，
                // 可确保不存在悬空网线，也不会推导出锁存器。
                for (tie_row = 0; tie_row < ROWS;
                     tie_row = tie_row + 1) begin: gen_tieoff
                    if (tie_row >= NEXT_DOTS) begin: gen_unused_point
                        assign wire_grid[(level_index + 1)*COLUMNS +
                                         column_index][tie_row] = 1'b0;
                    end
                end
            end
        end
    endgenerate

    // 末端两行输出：交给外部 CPA。压缩完成后两行中的进位已经位于真实权重列，
    // 因此外部 CPA 直接将 sum 与 carry 相加，不需要再次左移 carry。
    //
    // 重要语义说明：final_row_zero/final_row_one 只是“第 0 行/第 1 行”的名称。
    // 在多层压缩后，一列中的 row0 或 row1 可能来自旁路、FA/HA 的 sum，或相邻列
    // 产生的 cout；不能把整行机械地理解为纯本位和或纯进位。这里沿用
    // Wallace Tree 的接口约定：final_row_zero 导出为 carry，final_row_one 导出为
    // sum。交换这两个端口对外部的 sum+carry 结果没有影响，但统一命名便于连接。
    wire [COLUMNS-1:0] final_row_zero;
    wire [COLUMNS-1:0] final_row_one;

    genvar final_column;
    generate
        for (final_column = 0; final_column < COLUMNS;
             final_column = final_column + 1) begin: gen_final_rows
            assign final_row_zero[final_column] =
                wire_grid[LEVELS*COLUMNS + final_column][0];
            assign final_row_one[final_column] =
                wire_grid[LEVELS*COLUMNS + final_column][1];
        end
    endgenerate

    // 最高的哨兵列只用于承接压缩过程中的进位。OUT_WIDTH 已足以表示 N 个
    // K 位无符号操作数的和，因此只导出有效低位的两行。
    // 外部 CPA 应直接计算 sum + carry，不能再次将 carry 左移。
    // final_row_zero -> carry；final_row_one -> sum，保持与 Wallace Tree 相同。
    assign carry = final_row_zero[OUT_WIDTH-1:0];
    assign sum = final_row_one[OUT_WIDTH-1:0];

endmodule

// 恢复 Verilog 默认的隐式 wire 规则，避免污染同一编译单元中的其他模块。
`default_nettype wire
