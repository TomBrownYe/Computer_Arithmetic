// 可参数化的 Wallace Tree 多操作数加法器。
//
// 本模块把 N 个 K 位无符号操作数组织成“按位权分列”的点阵，
// 再使用 FA/HA 逐层做 carry-save compression，最终留下两行数据。
// 模块本身不执行最后的 carry-propagate addition；外部逻辑应计算 sum + carry。
// 与 Dadda Tree 的主要差别是：Wallace Tree 不预先规定每一层的目标列高，
// 而是在当前层只要存在超过 2 个点的列，就尽可能在所有列放置 FA/HA；
// 这样通常会减少压缩层数，但可能使用更多压缩器。
//
// data_in 是一个展平总线。第 i 个操作数位于 data_in[i*K +: K]，也就是：
//   data_in[0*K +: K]  = 第 0 个操作数
//   data_in[1*K +: K]  = 第 1 个操作数
//   ...
// 这种布局与 Dadda_Tree.v 保持一致，便于在同一个 testbench 中互换比较。
//
// carry_save_adder_in_8.v 适用于规则的三输入向量压缩，但向量 CSA 的 carry
// 端口不能直接表达每一列高度不规则、且必须跨到下一位权重列的 Wallace Tree
// 路由。因此这里例化一位 FA/HA；这些单元正是 Wallace Tree 中的 3:2、2:2
// counter，综合工具仍可以把它们映射为标准库中的 CSA 类逻辑。

// 直接包含一位压缩器的定义。FA.v/HA.v 自带宏保护，因此既可以只编译本文件，
// 也可以把 FA.v、HA.v 同时列入综合 source list，而不会重复定义模块。
`include "FA.v"
`include "HA.v"

// 在 include 之后为本模块明确指定仿真时间尺度，避免从被包含文件继承规则。
`timescale 1ns/1ps

// 禁止拼写错误自动生成隐式 1 位 wire；任何未声明的信号都会在编译时报告错误。
`default_nettype none

module Wallace_Tree #(
    // N：参与相加的操作数数量。N 必须为正整数。
    parameter N = 7,
    // K：每个操作数的位宽。K 必须为正整数。
    parameter K = 8
) (
    // 展平后的 N*K 位输入总线；第 i 个操作数位于 data_in[i*K +: K]。
    input  wire [N*K-1:0] data_in,
    // 压缩结束后保留的第一行数据，交给外部 CPA。
    output wire [K+$clog2(N)-1:0] sum,
    // 压缩结束后保留的第二行数据，交给外部 CPA。
    output wire [K+$clog2(N)-1:0] carry
);

    // OUT_WIDTH 是 N 个无符号 K 位操作数的最大和所需的位宽。
    // 最大值为 N*(2^K-1)，因此 K+$clog2(N) 位足以容纳结果。
    // $clog2(N) 对 N=1 返回 0，所以单个操作数仍保持 K 位输出。
    localparam integer OUT_WIDTH = K + $clog2(N);

    // ROWS 是每一个“层级、位列”网格位置能够存放的最大行数。
    // 输入层每列最多有 N 个点；N=1 时额外保留第 1 行，方便统一提取最终两行。
    // 额外行不会悬空，而是在输入织网中被显式接为 0。
    localparam integer ROWS = (N < 2) ? 2 : N;

    // LEVELS 是物理压缩层的上限。Wallace Tree 每层尽可能压缩所有超过两点的列，
    // 2*$clog2(N)+1 是一个保守上限，足以让常见参数下所有列收敛到最多两点。
    // 某个实例如果提前收敛，后续层的 ACTIVE 会为 0，只生成旁路连线。
    localparam integer LEVELS = (N <= 2) ? 1 : (2 * $clog2(N) + 1);

    // COLUMNS 是内部点阵的列数。
    // 前 K 列对应输入位权 0...K-1；每层产生的 carry 可能向右传播，
    // 因而还要为扩展列和最后的哨兵列预留空间。
    localparam integer COLUMNS = K + LEVELS + 1;

    // COUNT_BITS 是计数矩阵中记录“某列有多少个点”所需的位数。
    // $clog2(N+1) 能表示 0...N；N=1 时强制至少为 1 位，避免零宽向量。
    localparam integer COUNT_BITS = (N < 2) ? 1 : $clog2(N + 1);

    // MATRIX_BITS 是整个编译期点阵计数表的总位数。
    // 表中包含输入层 0 和每一层压缩后的结果层，共 LEVELS+1 层。
    localparam integer MATRIX_BITS = (LEVELS + 1) * COLUMNS * COUNT_BITS;

    // -------------------------------------------------------------------------
    // 编译期点阵计数矩阵
    // -------------------------------------------------------------------------
    // COUNT_MATRIX 的每个字段记录一个 (level, column) 位置的点数。
    // 该表只在 elaboration/generate 阶段计算，不会综合成运行时硬件。
    // Wallace Tree 的策略是：只要本层仍有任意列超过两点，就对每一列
    // 尽可能使用 FA/HA 压缩；如果整层已经全部不超过两点，则之后只旁路。
    // 这里返回 packed 向量而不是 unpacked localparam 数组，以兼容 Verilog-2001/2005。
    function automatic [MATRIX_BITS-1:0] make_count_matrix;
        // 一些 Verilog-2001 工具要求函数声明至少有一个输入；ignored 不参与计算。
        input integer ignored;
        // counts[column]：当前正在处理的层中，第 column 列的输入点数。
        integer counts [0:COLUMNS-1];
        // next_counts[column]：把当前层处理完后，下一层每列将拥有的点数。
        integer next_counts [0:COLUMNS-1];
        integer level;          // 当前压缩层编号；0 表示从输入层到第一层压缩。
        integer column;         // 当前扫描的位权列编号；0 是最低位列。
        integer fa_count;       // 当前列能够放置的 FA 数量，每个 FA 消耗 3 个点。
        integer remainder;      // 当前列除以 3 后剩余的点数，取值 0、1 或 2。
        integer local_count;    // FA/HA 的 sum 以及旁路点留在当前列的数量。
        integer carry_count;    // FA/HA 的 cout 向右侧下一列传播的数量。
        integer active;         // 本层是否至少存在一列高度大于 2。
        begin
            // 先清零整个返回向量；后续循环再写入每个 (level,column) 字段。
            make_count_matrix = {MATRIX_BITS{1'b0}};

            // 初始化输入层：每个操作数在位权 0...K-1 的每一列贡献一个点，
            // 所以低 K 列各有 N 个点；扩展列暂时没有输入点。
            for (column = 0; column < COLUMNS; column = column + 1) begin
                counts[column] = (column < K) ? N : 0;
                // level=0 的字段从 bit 0 开始，字段宽度是 COUNT_BITS。
                make_count_matrix[(column * COUNT_BITS) +: COUNT_BITS] =
                    counts[column];
            end

            // 逐层模拟点阵压缩，并把每层计算出的 next_counts 写回矩阵。
            for (level = 0; level < LEVELS; level = level + 1) begin
                // active 是整层开关，而不是单列开关：只要有一列超过 2 点，
                // 当前层所有列都会按 Wallace Tree 规则处理，已经较矮的列则使用
                // HA 或旁路，保证跨列 carry 的层级关系一致。
                active = 0;
                for (column = 0; column < COLUMNS; column = column + 1) begin
                    if (counts[column] > 2)
                        active = 1;
                end

                // 先清零下一层缓存，避免上一个 level 或上一个 column 的值残留。
                for (column = 0; column < COLUMNS; column = column + 1)
                    next_counts[column] = 0;

                for (column = 0; column < COLUMNS; column = column + 1) begin
                    if (active != 0) begin
                        // 每 3 个点使用一个 FA；整数除法得到 FA 数量，取模得到余数。
                        fa_count = counts[column] / 3;
                        remainder = counts[column] % 3;

                        // FA 的 sum 保留在本列；余数为 2 时剩余两个点使用 HA，
                        // 余数为 1 时剩余一个点直接旁路。两种情况下都会在本列
                        // 留下一个 local output，因此 local_count 是 FA 数加上余数非零标志。
                        local_count = fa_count + ((remainder != 0) ? 1 : 0);
                        // 每个 FA 产生一个 carry；余数为 2 的 HA 也产生一个 carry。
                        // 这些 carry 的物理列号加 1，因此它们的权重自动增加一位。
                        carry_count = fa_count + ((remainder == 2) ? 1 : 0);
                        // 本列保留 sum/HA sum/旁路点。
                        next_counts[column] = next_counts[column] + local_count;
                        // carry 进入下一列；最后的哨兵列保证这里通常不会越界。
                        if (column + 1 < COLUMNS)
                            next_counts[column + 1] =
                                next_counts[column + 1] + carry_count;
                    end
                    else begin
                        // 当整层已经收敛到最多两点时，不再插入任何压缩器，
                        // 原点数原样进入下一层，硬件只需要旁路连线。
                        next_counts[column] = counts[column];
                    end
                end

                // 将当前层处理结果推进到 counts，并写入矩阵的下一层字段。
                for (column = 0; column < COLUMNS; column = column + 1) begin
                    counts[column] = next_counts[column];
                    make_count_matrix[((level + 1) * COLUMNS + column) *
                                      COUNT_BITS +: COUNT_BITS] = counts[column];
                end
            end
        end
    endfunction

    // 调用一次函数，得到完整的编译期点阵计数表。
    // localparam 表示该值在 elaboration 时就确定，不会占用任何寄存器或组合逻辑。
    localparam [MATRIX_BITS-1:0] COUNT_MATRIX = make_count_matrix(0);

    // -------------------------------------------------------------------------
    // 编译期查询函数
    // -------------------------------------------------------------------------
    // 以下两个函数只被 generate/localparam 使用，用于把打包矩阵转换成可读的整数。
    function automatic integer matrix_count;
        input integer level;       // 要读取的层编号；0 是输入层。
        input integer column;      // 要读取的列编号；0 是最低有效位列。
        begin
            // 一个字段在 COUNT_MATRIX 中的起始位偏移为
            // (level*COLUMNS + column)*COUNT_BITS。
            matrix_count = COUNT_MATRIX[((level * COLUMNS + column) *
                                         COUNT_BITS) +: COUNT_BITS];
        end
    endfunction

    function automatic integer level_is_active;
        input integer level;       // 要判断的压缩层编号。
        integer column;             // 扫描该层所有列的循环变量。
        begin
            // 默认本层已经收敛；发现任意一列超过两个点后改为 1。
            level_is_active = 0;
            for (column = 0; column < COLUMNS; column = column + 1) begin
                if (matrix_count(level, column) > 2)
                    level_is_active = 1;
            end
        end
    endfunction

    // -------------------------------------------------------------------------
    // 三维点阵的 Verilog-2001 表示
    // -------------------------------------------------------------------------
    // 逻辑上 wire_grid 有三个坐标：
    //   level  ：压缩层编号；
    //   column ：位权列编号，列号每增加 1，数值权重增加一倍；
    //   row    ：同一列中自上而下堆叠的点。
    // Verilog-2001 对多维 memory 的综合支持不完全一致，因此将前两个坐标
    // 扁平化为 level*COLUMNS+column，保留 packed bit 作为 row：
    //   wire_grid[level*COLUMNS + column][row]
    // 这仍然是一个三维点阵，只是把 (level,column) 编码成了一个 memory 下标。
    // packed 的 row 维度不是普通总线的“不同位权”，而是同一位权下来自不同
    // 操作数/压缩器的多个独立点；这正是 Wallace Tree 点阵模型的核心。
    wire [ROWS-1:0] wire_grid [0:(LEVELS + 1)*COLUMNS-1];

    // -------------------------------------------------------------------------
    // 第 0 层：把展平输入总线解包为点阵，并为所有空位置接零
    // -------------------------------------------------------------------------
    // 输入层是 wire_grid 的第 0 层，因此其 memory 下标就是 column。
    // 对于输入操作数 i 的 bit j，点被放入 wire_grid[j][i]。

    genvar init_operand;       // 输入操作数编号。
    genvar init_bit;           // 当前操作数中的 bit 编号/位权列编号。
    genvar init_high_column;   // K 以上的扩展列编号。
    genvar init_extra_row;     // N=1 时为统一输出而保留的额外行编号。
    genvar init_extra_column;  // 额外行需要接零的列编号。
    generate
        // generate for 在 elaboration 阶段展开，不是运行时循环，也不会产生计数器。
        // 每个操作数的每一位都通过连续赋值连接到对应位权列。
        for (init_operand = 0; init_operand < N; init_operand = init_operand + 1) begin: gen_input_operand
            for (init_bit = 0; init_bit < K; init_bit = init_bit + 1) begin: gen_input_bit
                // init_operand*K 是第 init_operand 个操作数的起始位置，
                // 加上 init_bit 后得到该操作数的第 init_bit 位。
                assign wire_grid[init_bit][init_operand] = data_in[init_operand*K + init_bit];
            end

            // 原始 K 位操作数在 K 以上没有真实数据。扩展列中的输入行必须显式接 0，
            // 这样后续压缩器读到的是确定的 0/1，而不是悬空的 Z 或未知的 X。
            for (init_high_column = K; init_high_column < COLUMNS; init_high_column = init_high_column + 1) begin: gen_input_high_zero
                assign wire_grid[init_high_column][init_operand] = 1'b0;
            end
        end

        // 当 N=1 时 ROWS 被强制设为 2，因此 row=1 是没有真实操作数的空行。
        // 对所有列显式接零，保证最终 row1 以及中间每一层都没有悬空节点。
        for (init_extra_row = N; init_extra_row < ROWS; init_extra_row = init_extra_row + 1) begin: gen_input_extra_row
            for (init_extra_column = 0; init_extra_column < COLUMNS; init_extra_column = init_extra_column + 1) begin: gen_input_extra_zero
                assign wire_grid[init_extra_column][init_extra_row] = 1'b0;
            end
        end
    endgenerate

    // -------------------------------------------------------------------------
    // Wallace Tree 压缩织网
    // -------------------------------------------------------------------------
    // 下面的嵌套 generate 根据 COUNT_MATRIX 中的编译期常量，自动生成：
    //   1. FA：每 3 个同权输入点压缩成 1 个同列 sum 和 1 个下一列 carry；
    //   2. HA：某列剩余 2 个点时，将其压缩成 1 个 sum 和 1 个 carry；
    //   3. bypass：某列剩余 1 个点，或整层已经收敛时，直接连到下一层；
    //   4. tie-off：每层网格中未使用的行显式连接 0。
    // 所有连接都是 wire 连续赋值或模块组合逻辑，不会生成寄存器和锁存器。
    // 注意：level_index=0 表示从输入层到第一个压缩层的物理边界。
    genvar level_index;    // 压缩层生成变量。
    genvar column_index;   // 当前层中的位权列生成变量。
    genvar fa_index;       // 当前列中第几个 FA。
    genvar bypass_index;   // 当前列中用于检查旁路条件的行编号。
    genvar tie_row;        // 当前目标列中用于接零的行编号。
    generate
        for (level_index = 0; level_index < LEVELS; level_index = level_index + 1) begin: gen_level
            for (column_index = 0; column_index < COLUMNS; column_index = column_index + 1) begin: gen_column

                // 这些 localparam 都由 COUNT_MATRIX 和查询函数在 elaboration 时确定。
                // 因此 FA_COUNT、REMAINDER 等不是运行时信号，而是 generate 条件。
                localparam integer DOTS = matrix_count(level_index, column_index);
                // DOTS：本压缩层开始时，本列实际拥有的输入点数量。
                localparam integer ACTIVE = level_is_active(level_index);
                // ACTIVE：本层是否仍有任意一列超过两点；0 表示整层只旁路。
                localparam integer PREVIOUS_DOTS = (column_index == 0) ? 0 : matrix_count(level_index, column_index - 1);
                // PREVIOUS_DOTS：左邻列在同一层开始时的点数，用于估算左邻 carry 数。
                localparam integer FA_COUNT = (ACTIVE != 0) ? (DOTS / 3) : 0;
                // FA_COUNT：本列按 3 个点一组可放置的 FA 数量。
                localparam integer REMAINDER = (ACTIVE != 0) ? (DOTS % 3) : 0;
                // REMAINDER：FA 消耗后剩余 0/1/2 个本地点。
                localparam integer LOCAL_OUTPUTS = (ACTIVE != 0) ? (FA_COUNT + ((REMAINDER != 0) ? 1 : 0)) : DOTS;
                // LOCAL_OUTPUTS：本列留在同一列的 sum、HA sum 或旁路点数量。
                localparam integer PREVIOUS_CARRIES = (ACTIVE != 0) ? ((PREVIOUS_DOTS / 3) +
                                                      (((PREVIOUS_DOTS % 3) == 2) ? 1 : 0)) : 0;
                // PREVIOUS_CARRIES：左邻列送入本列、且已经占据本列前几行的 carry 数量。
                localparam integer NEXT_DOTS = matrix_count(level_index + 1, column_index);
                // NEXT_DOTS：计数函数预先算出的下一层本列总点数，用于判断哪些行接零。

                // 一个重要的行布局约定：
                //   row 0 ... PREVIOUS_CARRIES-1          ：左邻列传来的 carry；
                //   后续行                                ：本列 FA/HA 的 sum 或旁路点。
                // 本列生成的 carry 不留在当前列，而是连接到下一层的 column+1。
                for (fa_index = 0; fa_index < FA_COUNT; fa_index = fa_index + 1) begin: gen_fa
                    // 每个 FA 读取本列连续的三个输入行。
                    // FA 的关系是 a+b+cin = sum + 2*cout。
                    // 因此 sum 仍属于当前 column（权重不变），cout 则属于
                    // column+1（权重乘 2），这就是 carry-save 压缩的位权依据。
                    FA u_fa (
                        .a   (wire_grid[level_index*COLUMNS + column_index][3*fa_index]),
                        .b   (wire_grid[level_index*COLUMNS + column_index][3*fa_index + 1]),
                        .cin (wire_grid[level_index*COLUMNS + column_index][3*fa_index + 2]),
                        .sum (wire_grid[(level_index + 1)*COLUMNS + column_index]
                              [PREVIOUS_CARRIES + fa_index]),
                        .cout(wire_grid[(level_index + 1)*COLUMNS + column_index + 1][fa_index])
                    );

                end

                // 当余数为 2 时，两个没有被 FA 使用的点由 HA 压缩。
                // HA 的 sum 放在当前列，cout 连接到下一列；当余数不是 2 时，
                // 该 generate-if 完全不展开，不会多生成硬件。
                if ((ACTIVE != 0) && (REMAINDER == 2)) begin: gen_ha
                    // HA 的关系是 a+b = sum + 2*cout，和 FA 相同地把 cout
                    // 放到下一列，只是没有第三个 cin 输入。
                    HA u_ha (
                        .a   (wire_grid[level_index*COLUMNS + column_index][3*FA_COUNT]),
                        .b   (wire_grid[level_index*COLUMNS + column_index][3*FA_COUNT + 1]),
                        .sum (wire_grid[(level_index + 1)*COLUMNS + column_index]
                              [PREVIOUS_CARRIES + FA_COUNT]),
                        .cout(wire_grid[(level_index + 1)*COLUMNS + column_index + 1][FA_COUNT])
                    );

                end

                // 旁路有两种情况：
                //   1. ACTIVE=1 且 REMAINDER=1：FA 后剩余一个点，直接留在本列；
                //   2. ACTIVE=0：整层已经收敛，本列所有 DOTS 个点都原样传递。
                // 旁路不会改变点的位权，也不会增加逻辑门延迟。
                for (bypass_index = 0; bypass_index < ROWS; bypass_index = bypass_index + 1) begin: gen_bypass
                    if (((ACTIVE == 0) && (bypass_index < DOTS)) ||
                        ((ACTIVE != 0) && (REMAINDER == 1) &&
                         (bypass_index == 3*FA_COUNT))) begin: gen_bypass_used
                        // 压缩层开启时，旁路点要排在左邻 carry 和本列压缩 sum 之后；
                        // 整层关闭时，所有点原行号保持不变。
                        assign wire_grid[(level_index + 1)*COLUMNS + column_index]
                               [((ACTIVE == 0) ? bypass_index :
                                 (PREVIOUS_CARRIES + LOCAL_OUTPUTS - 1))] =
                            wire_grid[level_index*COLUMNS + column_index][bypass_index];

                    end
                end

                // 目标列中 NEXT_DOTS 以上的行没有真实数据。显式接 0 可以：
                //   - 避免 wire 悬空后产生 Z/X；
                //   - 保证后续层读取到确定值；
                //   - 避免综合工具误判为需要存储状态的锁存器。
                // 小于 NEXT_DOTS 的有效行已经分别由 carry、sum 或 bypass 驱动一次。
                for (tie_row = 0; tie_row < ROWS; tie_row = tie_row + 1) begin: gen_tieoff
                    if (tie_row >= NEXT_DOTS)
                        assign wire_grid[(level_index + 1)*COLUMNS + column_index][tie_row] = 1'b0;
                end
            end
        end
    endgenerate

    // -------------------------------------------------------------------------
    // 末端两行输出：交给外部 CPA
    // -------------------------------------------------------------------------
    // 经过最后一层后，每一列最多剩余两个点。下面把 row0、row1 读取成两个
    // 等宽向量，作为 carry-save 表示交给外部 CPA。
    // 注意：这两个向量不是已经完成相加的最终整数，外部应直接计算 sum + carry。
    // 由于每个 FA/HA 的 cout 在生成时已经连接到 column+1，进位的位权已经
    // 在点阵路由中体现，因此外部 CPA 不应再次把 carry 左移一位。
    //
    // final_row_zero/final_row_one 是物理行名，不表示其中一行必然只含 FA sum、
    // 另一行必然只含 FA carry。多层压缩后，一行可能同时包含旁路点、sum 和
    // 从相邻列传入的 carry。两行交换不会改变 sum+carry 的数值；这里的命名
    // 只需与 Wallace Tree/Dadda Tree 的接口约定保持一致。
    wire [COLUMNS-1:0] final_row_zero;
    wire [COLUMNS-1:0] final_row_one;

    genvar final_column; // 用于遍历所有内部列的 elaboration-time 生成变量。
    generate
        for (final_column = 0; final_column < COLUMNS; final_column = final_column + 1) begin: gen_final_rows
            // 从最后一层 wire_grid 的 row0、row1 取出对应位权列的两个点。
            assign final_row_zero[final_column] = wire_grid[LEVELS*COLUMNS + final_column][0];
            assign final_row_one[final_column] = wire_grid[LEVELS*COLUMNS + final_column][1];
        end
    endgenerate

    // 最高的哨兵列只用于承接压缩过程的内部进位。N 个 K 位无符号数的理论
    // 输出宽度 OUT_WIDTH 已足够，因此只导出两个最终行的有效低 OUT_WIDTH 位。
    // 沿用 Wallace Tree 的端口约定：row0 接 carry，row1 接 sum。
    // 这不是 FA/HA 的 sum/cout 接反，而是两条最终 carry-save 行的接口命名。
    assign carry = final_row_zero[OUT_WIDTH-1:0];
    assign sum = final_row_one[OUT_WIDTH-1:0];

endmodule

// 恢复 Verilog 默认的隐式 wire 规则，避免影响同一编译单元中后续的其他模块。
`default_nettype wire
