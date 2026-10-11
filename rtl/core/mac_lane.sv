// mac_lane.sv — one signed INT8 x INT8 multiply-accumulate lane with an INT32 accumulator; the product is registered, so a sum lands two clocks after its operands.

module mac_lane (
    input   logic clk, load_bias, accumulate_en,
            logic signed[7:0]  activation, weight,
            logic signed[31:0] bias,

    output  logic signed[31:0] accumulator
);

(* use_dsp = "yes" *) logic signed[15:0] product;
logic accumulate_pending;

always_ff @(posedge clk) begin
    product            <= activation * weight;
    accumulate_pending <= accumulate_en;
end

always_ff @(posedge clk) begin
    if (load_bias)               accumulator <= bias;
    else if (accumulate_pending) accumulator <= accumulator + product;
end

endmodule
