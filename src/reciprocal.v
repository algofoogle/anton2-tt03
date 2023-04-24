// Fixed-point reciprocal for Q6.10, borrowed and adapted from:
// https://github.com/ameetgohil/reciprocal-sv/blob/master/rtl/reciprocal.sv
// See also: https://observablehq.com/@drom/reciprocal-approximation

`default_nettype none
`timescale 1ns / 1ps


module reciprocal(
    input   wire[15:0]  i_data,
    input   wire        i_abs,  // 1=we want the absolute value only.
    output  wire[15:0]  o_data,
    output  wire        o_sat   // 1=saturated
);

    //QM.N M= 6, N= 10
    localparam bit[4:0] M = 6;
    //localparam [9:0] N= 10;

    /*
    Reciprocal algorithm for numbers in the range [0.5,1)
    a = input
    b = 1.466 - a
    c = a * b;
    d = 1.0012 - c
    e = d * b;
    output = e * 4;
    */

    wire [4:0]   lzc_cnt, rescale_lzc;
    wire [15:0]  a, b, d, f, reci, sat_data, scale_data;
    wire [31:0]  rescale_data;
    wire         sign;   // Does this need to be a reg? Shouldn't it be a wire?
    wire [15:0]  unsigned_data;

    /* verilator lint_off UNUSED */
    wire [31:0]  c, e;
    /* verilator lint_on UNUSED */

    assign sign = i_data[15];

    assign unsigned_data = sign ? (~i_data + 1'b1) : i_data;

    // lzc#(.WIDTH(16)) lzc_inst(.i_data(unsigned_data), .lzc_cnt(lzc_cnt));
    //SMELL: This was using https://github.com/ameetgohil/leading-zeroes-counter,
    // but because iverilog doesn't work properly with it (?) I've replaced it with
    // the following ugliness:
    assign lzc_cnt =
        unsigned_data[15: 0]==0 ? 16 :
        unsigned_data[15: 1]==0 ? 15 :
        unsigned_data[15: 2]==0 ? 14 :
        unsigned_data[15: 3]==0 ? 13 :
        unsigned_data[15: 4]==0 ? 12 :
        unsigned_data[15: 5]==0 ? 11 :
        unsigned_data[15: 6]==0 ? 10 :
        unsigned_data[15: 7]==0 ?  9 :
        unsigned_data[15: 8]==0 ?  8 :
        unsigned_data[15: 9]==0 ?  7 :
        unsigned_data[15:10]==0 ?  6 :
        unsigned_data[15:11]==0 ?  5 :
        unsigned_data[15:12]==0 ?  4 :
        unsigned_data[15:13]==0 ?  3 :
        unsigned_data[15:14]==0 ?  2 :
        unsigned_data[15:15]==0 ?  1 :
                                   0;

    assign rescale_lzc = $signed(M) - $signed(lzc_cnt);

    //scale input data to be b/w .5 and 1 for accurate reciprocal result
    assign scale_data = M >= lzc_cnt ? unsigned_data >>> (M-lzc_cnt): unsigned_data <<< (lzc_cnt - M);

    assign a = scale_data;

    //1.466 in Q6.10 is 16'h5dd - See fixed2float project on github for conversion
    assign b = 16'h5dd - a;

    assign c = $signed(a) * $signed(b);

    //1.0012 in Q6.10 is 16'h401 - See fixed2float project on github for conversion
    assign d = 16'h401 - $signed(c[25:10]);

    assign e = $signed(d) * $signed(b);

    assign f = e[25:10];

    assign reci = |f[15:14] ? 16'h7FFF : f << 2; //saturation detection and (e*4)

    //rescale reci to by the lzc factor

    assign rescale_data = rescale_lzc[4] ? {16'b0,reci} << (~rescale_lzc + 1'b1) : {16'b0,reci} >> rescale_lzc;

    //Saturation logic
    assign o_sat = |rescale_data[31:15];
    assign sat_data = o_sat ? 16'h7FFF : rescale_data[15:0];

    assign o_data = (sign && !i_abs) ? (~sat_data + 1'b1) : sat_data;

endmodule
