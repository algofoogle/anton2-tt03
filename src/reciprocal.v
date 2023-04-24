// Fixed-point reciprocal for Q6.10, borrowed and adapted from:
// https://github.com/ameetgohil/reciprocal-sv/blob/master/rtl/reciprocal.sv
// See also: https://observablehq.com/@drom/reciprocal-approximation

`default_nettype none
`timescale 1ns / 1ps


function [4:0] lzc(input [15:0] data);
    casex(data)
        16'b0000000000000000:   lzc = 16;
        16'b0000000000000001:   lzc = 15;
        16'b000000000000001x:   lzc = 14;
        16'b00000000000001xx:   lzc = 13;
        16'b0000000000001xxx:   lzc = 12;
        16'b000000000001xxxx:   lzc = 11;
        16'b00000000001xxxxx:   lzc = 10;
        16'b0000000001xxxxxx:   lzc = 9;
        16'b000000001xxxxxxx:   lzc = 8;
        16'b00000001xxxxxxxx:   lzc = 7;
        16'b0000001xxxxxxxxx:   lzc = 6;
        16'b000001xxxxxxxxxx:   lzc = 5;
        16'b00001xxxxxxxxxxx:   lzc = 4;
        16'b0001xxxxxxxxxxxx:   lzc = 3;
        16'b001xxxxxxxxxxxxx:   lzc = 2;
        16'b01xxxxxxxxxxxxxx:   lzc = 1;
        default:                lzc = 0;
    endcase
endfunction


module reciprocal(
    input   wire[15:0]  i_data,
    // input   wire        i_abs,  // 1=we want the absolute value only.
    // output  wire        o_sat   // 1=saturated
    output  wire[15:0]  o_data
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
    // wire [31:0]  rescale_data;
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

    assign lzc_cnt = lzc(unsigned_data);

    // assign lzc_cnt =
    //     unsigned_data[15: 0]==0 ? 16 :
    //     unsigned_data[15: 1]==0 ? 15 :
    //     unsigned_data[15: 2]==0 ? 14 :
    //     unsigned_data[15: 3]==0 ? 13 :
    //     unsigned_data[15: 4]==0 ? 12 :
    //     unsigned_data[15: 5]==0 ? 11 :
    //     unsigned_data[15: 6]==0 ? 10 :
    //     unsigned_data[15: 7]==0 ?  9 :
    //     unsigned_data[15: 8]==0 ?  8 :
    //     unsigned_data[15: 9]==0 ?  7 :
    //     unsigned_data[15:10]==0 ?  6 :
    //     unsigned_data[15:11]==0 ?  5 :
    //     unsigned_data[15:12]==0 ?  4 :
    //     unsigned_data[15:13]==0 ?  3 :
    //     unsigned_data[15:14]==0 ?  2 :
    //     unsigned_data[15:15]==0 ?  1 :
    //                                0;

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

    //SMELL: I had to disable saturation detection to get this to fit in TT03.
    //assign reci = |f[15:14] ? 16'h7FFF : f << 2; //saturation detection and (e*4)
    assign reci = f << 2; // e*4

    //rescale reci to by the lzc factor

    // assign rescale_data = rescale_lzc[4] ? {16'b0,reci} << (~rescale_lzc + 1'b1) : {16'b0,reci} >> rescale_lzc;

    //Saturation logic DISABLED for fit in TT03.
    // assign sat_data = |rescale_data[31:15] ? 16'h7FFF : rescale_data[15:0];
    assign sat_data = rescale_lzc[4] ? reci << (~rescale_lzc + 1'b1) : reci >> rescale_lzc;

    assign o_data = sign ? (~sat_data + 1'b1) : sat_data;

endmodule
