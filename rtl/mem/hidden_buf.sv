// hidden_buf.sv — 32 INT8 hidden activations stored as four 64-bit groups; read one byte at a time with no clock delay.
// This holds the hidden layer's outputs (scratch, rewritten every inference), not weights; the hidden layer weights are words 0-127 of weight_rom.

module hidden_buf (
    input   logic clk, hidden_we,
            logic[1:0]  group_index,
            logic[4:0]  input_index,
            logic[63:0] hidden_word,

    output  logic signed[7:0] hidden_activation
);

logic[255:0] storage;

always_ff @(posedge clk) begin
    if (hidden_we) storage[64*group_index +: 64] <= hidden_word;
end

assign hidden_activation = storage[8*input_index +: 8];

endmodule
