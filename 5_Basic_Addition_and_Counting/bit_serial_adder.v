//本架构基于Fig5.3a
module bit_serial_adder #(
    parameter WIDTH = 32
) (
    input wire [WIDTH-1:0] x,
    input wire [WIDTH-1:0] y,
    input                  clk,
    input                  rst_n,
    input                  start,

    output reg [WIDTH-1:0] sum,
    output reg             vld
);

reg [WIDTH-1:0] x_shift;
reg [WIDTH-1:0] y_shift;
reg             carry_latch;
reg [$clog2(WIDTH):0] count;

wire sum_bit = x_shift[0] ^ y_shift[0] ^ carry_latch;
wire carry_bit = (x_shift[0] & y_shift[0])
 | (carry_latch & (x_shift[0] ^ y_shift[0]));

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        x_shift <= 0;
        y_shift <= 0;
        carry_latch <= 0;
        count <= 0;
        sum <= 0;
        vld <= 0;
    end
    else if (start)begin
        x_shift <= x;
        y_shift <= y;
        carry_latch <= 0;
        count <= 0;
        sum <= 0;
        vld <= 0;
    end
    else if(count < WIDTH)begin
        carry_latch <= carry_bit;
        x_shift <= x_shift >> 1;
        y_shift <= y_shift >> 1;
        sum <= {sum_bit, sum[WIDTH-1:1]};
        count <= count + 1;

        if(count == WIDTH - 1)begin
            vld <= 1;
        end
    end
end
endmodule