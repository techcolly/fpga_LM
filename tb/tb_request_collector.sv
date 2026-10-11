// tb_request_collector.sv — checks token capture, the single start pulse, token selection, busy blocking, and 6-bit masking.

module tb_request_collector;

logic       clk, reset, rx_valid, busy, start;
logic[7:0]  rx_data;
logic[1:0]  token_index;
logic[5:0]  embed_address;

int         errors, start_count;

request_collector dut (.*);

initial clk = 1'b0;
always #5 clk = ~clk;

always @(posedge clk) begin
    if (start) start_count++;
end

task receive_byte(input logic[7:0] value);
    rx_data  = value;
    rx_valid = 1'b1;
    @(negedge clk);
    rx_valid = 1'b0;
    @(negedge clk);
endtask

task check_token(input int index, input int expected_value);
    token_index = index;
    #1;
    if (embed_address !== expected_value) begin
        $display("FAIL token %0d: embed_address is %0d, expected %0d", index, embed_address, expected_value);
        errors++;
    end
endtask

task check_start_count(input int expected_value, input string message);
    if (start_count !== expected_value) begin
        $display("FAIL %s: start pulsed %0d times, expected %0d", message, start_count, expected_value);
        errors++;
    end
endtask

initial begin
    errors      = 0;
    start_count = 0;
    reset       = 1'b1;
    rx_valid    = 1'b0;
    busy        = 1'b0;
    rx_data     = 8'd0;
    token_index = 2'd0;
    repeat (3) @(negedge clk);
    reset = 1'b0;
    @(negedge clk);

    // first request: four bytes, start pulses once after the fourth
    receive_byte(8'd5);
    receive_byte(8'd63);
    receive_byte(8'd0);
    check_start_count(0, "before the fourth byte");
    receive_byte(8'd17);
    check_start_count(1, "after the fourth byte");
    check_token(0, 5);
    check_token(1, 63);
    check_token(2, 0);
    check_token(3, 17);

    // second request replaces the tokens, and start pulses again
    receive_byte(8'd1);
    receive_byte(8'd2);
    receive_byte(8'd3);
    receive_byte(8'd4);
    check_start_count(2, "second request");
    check_token(0, 1);
    check_token(1, 2);
    check_token(2, 3);
    check_token(3, 4);

    // bytes arriving while busy are dropped and do not advance the byte counter
    busy = 1'b1;
    receive_byte(8'd40);
    receive_byte(8'd41);
    receive_byte(8'd42);
    receive_byte(8'd43);
    check_start_count(2, "while busy");
    check_token(0, 1);
    check_token(3, 4);
    busy = 1'b0;

    // the next request after busy drops starts cleanly at token 0
    receive_byte(8'd10);
    receive_byte(8'd11);
    receive_byte(8'd12);
    receive_byte(8'd13);
    check_start_count(3, "request after busy");
    check_token(0, 10);
    check_token(3, 13);

    // only the low 6 bits of a byte are kept
    receive_byte(8'hC5);
    receive_byte(8'hFF);
    receive_byte(8'h40);
    receive_byte(8'h7F);
    check_token(0, 5);
    check_token(1, 63);
    check_token(2, 0);
    check_token(3, 63);

    if (errors == 0) $display("PASS: request_collector");
    else             $display("FAIL: %0d errors", errors);
    $finish;
end

endmodule
