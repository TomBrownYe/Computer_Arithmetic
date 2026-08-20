//本模块为各种前缀和加法树的子模块cent.v
//(g,p) = (g_right,p_right) cent （g_left，p_left）
module cent (
    input g_right,
    input g_left,
    input p_right,
    input p_left,

    output G_out,
    output P_out  
);

assign G_out = g_left | (g_right & p_left);
assign P_out = p_left & p_right;

endmodule 