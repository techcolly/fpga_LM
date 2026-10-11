// weight_rom.sv — 384 words of 8 INT8 weights (hidden layer words 0-127, output layer words 128-383); data is valid one clock after address.

module weight_rom #(
    parameter string INIT_FILE = "weight_rom.mem"
) (
    input   logic clk,
            logic[8:0] address,

    output  logic[63:0] data
);

(* rom_style = "block" *) logic[63:0] memory[384];

initial $readmemh(INIT_FILE, memory);

always_ff @(posedge clk) data <= memory[address];

endmodule
