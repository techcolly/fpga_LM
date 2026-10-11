// tb_fpga_top.sv — sends 4 token bytes over the serial input, decodes the reply byte, and compares it with an independent integer reference.

module tb_fpga_top;

localparam int CLOCKS_PER_BIT = 16;

logic       clk, reset_button, uart_txd_in, uart_rxd_out;
logic[3:0]  led;

logic[63:0]   weight_words[384];
logic[255:0]  bias_words[12];
logic[63:0]   embed_words[64];

int           errors;

fpga_top #(
    .CLOCKS_PER_BIT (CLOCKS_PER_BIT),
    .WEIGHT_FILE    ("test_weight_rom.mem"),
    .BIAS_FILE      ("test_bias_rom.mem"),
    .EMBED_FILE     ("test_embed_rom.mem")
) dut (
    .CLK100MHZ    (clk),
    .reset_button (reset_button),
    .uart_txd_in  (uart_txd_in),
    .uart_rxd_out (uart_rxd_out),
    .led          (led)
);

initial clk = 1'b0;
always #5 clk = ~clk;

// reference model: the loops from nn_math_walkthrough, written independently of the hardware
function int expected_token(input int tokens[4]);
    int reference_inputs[32], reference_hidden[32], reference_logits[64];
    int accumulator, shifted, best_value, best_token;
    logic signed[7:0]  activation_byte, weight_byte;
    logic signed[31:0] bias_value;

    for (int token_number = 0; token_number < 4; token_number++)
        for (int element = 0; element < 8; element++) begin
            activation_byte = embed_words[tokens[token_number]][8*element +: 8];
            reference_inputs[8*token_number + element] = activation_byte;
        end

    for (int group_number = 0; group_number < 4; group_number++)
        for (int lane = 0; lane < 8; lane++) begin
            bias_value  = bias_words[group_number][32*lane +: 32];
            accumulator = bias_value;
            for (int input_number = 0; input_number < 32; input_number++) begin
                weight_byte = weight_words[group_number*32 + input_number][8*lane +: 8];
                accumulator = accumulator + reference_inputs[input_number] * weight_byte;
            end
            if (accumulator < 0) shifted = 0;
            else                 shifted = accumulator >>> 4;
            if (shifted > 127) shifted = 127;
            reference_hidden[8*group_number + lane] = shifted;
        end

    for (int group_number = 0; group_number < 8; group_number++)
        for (int lane = 0; lane < 8; lane++) begin
            bias_value  = bias_words[4 + group_number][32*lane +: 32];
            accumulator = bias_value;
            for (int input_number = 0; input_number < 32; input_number++) begin
                weight_byte = weight_words[128 + group_number*32 + input_number][8*lane +: 8];
                accumulator = accumulator + reference_hidden[input_number] * weight_byte;
            end
            reference_logits[8*group_number + lane] = accumulator;
        end

    best_value = reference_logits[0];
    best_token = 0;
    for (int index = 1; index < 64; index++)
        if (reference_logits[index] > best_value) begin
            best_value = reference_logits[index];
            best_token = index;
        end
    return best_token;
endfunction

task send_byte(input logic[7:0] value);
    uart_txd_in = 1'b0;
    repeat (CLOCKS_PER_BIT) @(negedge clk);
    for (int bit_number = 0; bit_number < 8; bit_number++) begin
        uart_txd_in = value[bit_number];
        repeat (CLOCKS_PER_BIT) @(negedge clk);
    end
    uart_txd_in = 1'b1;
    repeat (CLOCKS_PER_BIT) @(negedge clk);
endtask

task receive_byte(output logic[7:0] value, output bit ok);
    int waited;

    ok     = 1'b1;
    value  = 8'd0;
    waited = 0;
    while (uart_rxd_out !== 1'b0 && waited < 40000) begin
        @(negedge clk);
        waited++;
    end
    if (waited >= 40000) begin
        ok = 1'b0;
        return;
    end
    repeat (CLOCKS_PER_BIT / 2) @(negedge clk);
    if (uart_rxd_out !== 1'b0) ok = 1'b0;
    for (int bit_number = 0; bit_number < 8; bit_number++) begin
        repeat (CLOCKS_PER_BIT) @(negedge clk);
        value[bit_number] = uart_rxd_out;
    end
    repeat (CLOCKS_PER_BIT) @(negedge clk);
    if (uart_rxd_out !== 1'b1) ok = 1'b0;
endtask

task run_request(input int tokens[4]);
    logic[7:0] reply;
    bit        reply_ok;
    int        expected_value;

    expected_value = expected_token(tokens);
    for (int token_number = 0; token_number < 4; token_number++) send_byte(tokens[token_number]);
    receive_byte(reply, reply_ok);

    if (!reply_ok) begin
        $display("FAIL tokens %0d %0d %0d %0d: no valid reply frame", tokens[0], tokens[1], tokens[2], tokens[3]);
        errors++;
    end else if (reply !== expected_value || led !== expected_value[3:0]) begin
        $display("FAIL tokens %0d %0d %0d %0d: reply %0d led %0d, expected %0d",
                 tokens[0], tokens[1], tokens[2], tokens[3], reply, led, expected_value);
        errors++;
    end else begin
        $display("ok   tokens %0d %0d %0d %0d -> %0d", tokens[0], tokens[1], tokens[2], tokens[3], reply);
    end
    repeat (2 * CLOCKS_PER_BIT) @(negedge clk);
endtask

initial begin
    #50000000;
    $display("FAIL: timeout at %0t", $time);
    $finish;
end

initial begin
    int tokens[4];

    errors       = 0;
    reset_button = 1'b1;
    uart_txd_in  = 1'b1;
    $readmemh("test_weight_rom.mem", weight_words);
    $readmemh("test_bias_rom.mem",   bias_words);
    $readmemh("test_embed_rom.mem",  embed_words);
    repeat (10) @(negedge clk);
    reset_button = 1'b0;
    repeat (10) @(negedge clk);

    tokens = '{0, 1, 2, 3};
    run_request(tokens);
    tokens = '{63, 0, 63, 0};
    run_request(tokens);
    tokens = '{5, 5, 5, 5};
    run_request(tokens);

    repeat (30) begin
        for (int token_number = 0; token_number < 4; token_number++) tokens[token_number] = $urandom_range(0, 63);
        run_request(tokens);
    end

    if (errors == 0) $display("PASS: fpga_top");
    else             $display("FAIL: %0d errors", errors);
    $finish;
end

endmodule
