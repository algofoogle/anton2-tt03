`default_nettype none

//NOTE: This is called "tracer" because it is a small piece of a larger
// ray-casting engine I was working on. See here for more info:
// https://github.com/algofoogle/raybox
module algofoogle_tracer(
    input   [7:0] io_in,
    output  [7:0] io_out
);
    wire            clk     = io_in[0];
    wire            reset   = io_in[1];
    wire            abs     = io_in[2];
    wire [3:0]      i_data  = io_in[7:4];

    reg [2:0]       step;       // Nibbles in/out counter.
    reg [5:-10]     operand;    // Q6.10 fixed-point operand.
    reg [5:-10]     result;     // Reciprocal result.
    assign io_out = result[5:-2];   // Output top 8 bits of the result, at all times.

    wire            saturated;  // Unused here.
    wire [5:-10]    reciprocal_out;

    reciprocal reciprocal(
        .i_data (operand),
        .i_abs  (abs),
        .o_sat  (saturated),
        .o_data (reciprocal_out)
    );

    always @(posedge clk) begin
        if (reset) begin
            step <= 0;
            operand <= 0;
            result <= 0;
        end else begin
            //NOTE: Could probably change this state machine to start
            // producing output on the same step as the final nibble
            // loading, but I'm keeping it this way because I might
            // have other steps in a more complicated design later.
            if (step < 4) begin
                operand <= {operand[1:-10], i_data};
            end else if (step == 4) begin
                result <= reciprocal_out;
            end else if (step == 5) begin
                result <= result << 8;
            end
            step <= (step==5) ? 0 : step + 1;
        end
    end

endmodule
