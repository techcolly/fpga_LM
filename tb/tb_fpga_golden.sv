// tb_fpga_golden.sv — replays the exported golden vectors (from the Python int_forward reference) through the real fpga_top over the serial port.

module tb_fpga_golden;

localparam int CLOCKS_PER_BIT = 16;
localparam int MAX_VECTORS    = 1024;

logic       clk, reset_button, uart_txd_in, uart_rxd_out;
logic[3:0]  led;

logic[39:0] golden[MAX_VECTORS];
int         errors, vector_count;

fpga_top #(.CLOCKS_PER_BIT(CLOCKS_PER_BIT)) dut (
    .CLK100MHZ    (clk),
    .reset_button (reset_button),
    .uart_txd_in  (uart_txd_in),
    .uart_rxd_out (uart_rxd_out),
    .led          (led)
);

initial clk = 1'b0;
always #5 clk = ~clk;

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

initial begin
    #1000000000;
    $display("FAIL: timeout at %0t", $time);
    $finish;
end

initial begin
    logic[7:0] reply;
    bit        reply_ok;
    logic[7:0] token_0, token_1, token_2, token_3, expected_token;

    errors       = 0;
    vector_count = 0;
    reset_button = 1'b1;
    uart_txd_in  = 1'b1;
    $readmemh("golden_vectors.mem", golden);
    while (vector_count < MAX_VECTORS && !$isunknown(golden[vector_count])) vector_count++;
    $display("replaying %0d golden vectors", vector_count);

    repeat (10) @(negedge clk);
    reset_button = 1'b0;
    repeat (10) @(negedge clk);

    for (int index = 0; index < vector_count; index++) begin
        {expected_token, token_3, token_2, token_1, token_0} = golden[index];
        send_byte(token_0);
        send_byte(token_1);
        send_byte(token_2);
        send_byte(token_3);
        receive_byte(reply, reply_ok);

        if (!reply_ok) begin
            if (errors < 20) $display("FAIL vector %0d (%0d %0d %0d %0d): no valid reply frame", index, token_0, token_1, token_2, token_3);
            errors++;
        end else if (reply !== expected_token || led !== expected_token[3:0]) begin
            if (errors < 20) $display("FAIL vector %0d (%0d %0d %0d %0d): reply %0d led %0d, expected %0d",
                                      index, token_0, token_1, token_2, token_3, reply, led, expected_token);
            errors++;
        end
        repeat (2 * CLOCKS_PER_BIT) @(negedge clk);
        if (index % 100 == 99) $display("%0d vectors done, %0d errors so far", index + 1, errors);
    end

    if (errors == 0) $display("PASS: fpga_top matches the Python reference on %0d golden vectors", vector_count);
    else             $display("FAIL: %0d of %0d vectors wrong", errors, vector_count);
    $finish;
end

endmodule
