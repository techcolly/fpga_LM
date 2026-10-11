// request_collector.sv — collects four received bytes into four 6-bit token IDs, pulses start, and selects one token for the embedding ROM.

module request_collector (
    input   logic clk, reset, rx_valid, busy,
            logic[7:0] rx_data,
            logic[1:0] token_index,

    output  logic      start,
            logic[5:0] embed_address
);

logic[1:0] byte_count;
logic[5:0] tokens[4];

always_ff @(posedge clk) begin
    start <= 1'b0;

    if (reset) begin
        byte_count <= 2'd0;
    end else if (rx_valid && !busy) begin
        tokens[byte_count] <= rx_data[5:0];
        byte_count         <= byte_count + 2'd1;
        if (byte_count == 2'd3) start <= 1'b1;
    end
end

assign embed_address = tokens[token_index];

endmodule
