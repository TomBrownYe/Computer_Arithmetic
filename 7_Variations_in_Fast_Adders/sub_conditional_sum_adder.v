//本模块参见Fig7.11，是条件求和加法器的子模块
module sub_conditional_sum_adder(
    input x,
    input y,
    input ci,
    
    output co,
    output si
);
    wire cout_1,cout_0,si_1,si_0;

    assign cout_0 = x & y;
    assign si_0 = x ^ y;

    assign cout_1 = x | y;
    assign si_1 = ~si_0;

    assign co = ci ? cout_1 : cout_0;
    assign si = ci ? si_1 : si_0;

endmodule