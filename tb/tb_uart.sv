// tb_uart.sv — checks uart_rx and uart_tx separately against hand-built frames, then in loopback at 16 and 868 clocks per bit.

module tb_uart;

localparam int CLOCKS_PER_BIT      = 16;
localparam int SLOW_CLOCKS_PER_BIT = 868;

logic       clk, reset;
logic       rx_line, rx_valid;
logic[7:0]  rx_data;
logic       send, tx_busy, tx_line;
logic[7:0]  tx_data;
logic       loop_send, loop_busy, loop_line, loop_valid;
logic[7:0]  loop_send_data, loop_data;
logic       slow_send, slow_busy, slow_line, slow_valid;
logic[7:0]  slow_send_data, slow_data;

int         errors, rx_count, loop_count, slow_count;
logic[7:0]  last_rx_data, last_loop_data, last_slow_data;

uart_rx #(.CLOCKS_PER_BIT(CLOCKS_PER_BIT))      rx_unit   (.clk(clk), .reset(reset), .rx(rx_line), .data(rx_data), .data_valid(rx_valid));
uart_tx #(.CLOCKS_PER_BIT(CLOCKS_PER_BIT))      tx_unit   (.clk(clk), .reset(reset), .send(send), .data(tx_data), .tx(tx_line), .busy(tx_busy));
uart_tx #(.CLOCKS_PER_BIT(CLOCKS_PER_BIT))      loop_tx   (.clk(clk), .reset(reset), .send(loop_send), .data(loop_send_data), .tx(loop_line), .busy(loop_busy));
uart_rx #(.CLOCKS_PER_BIT(CLOCKS_PER_BIT))      loop_rx   (.clk(clk), .reset(reset), .rx(loop_line), .data(loop_data), .data_valid(loop_valid));
uart_tx #(.CLOCKS_PER_BIT(SLOW_CLOCKS_PER_BIT)) slow_tx   (.clk(clk), .reset(reset), .send(slow_send), .data(slow_send_data), .tx(slow_line), .busy(slow_busy));
uart_rx #(.CLOCKS_PER_BIT(SLOW_CLOCKS_PER_BIT)) slow_rx   (.clk(clk), .reset(reset), .rx(slow_line), .data(slow_data), .data_valid(slow_valid));

initial clk = 1'b0;
always #5 clk = ~clk;

always @(posedge clk) begin
    if (rx_valid)   begin rx_count++;   last_rx_data   = rx_data;   end
    if (loop_valid) begin loop_count++; last_loop_data = loop_data; end
    if (slow_valid) begin slow_count++; last_slow_data = slow_data; end
end

task fail(input string message);
    $display("FAIL at %0t: %s", $time, message);
    errors++;
endtask

// ---- receiver tests: the testbench bit-bangs rx_line ----

task send_rx_frame(input logic[7:0] value, input logic stop_bit);
    rx_line = 1'b0;
    repeat (CLOCKS_PER_BIT) @(negedge clk);
    for (int bit_number = 0; bit_number < 8; bit_number++) begin
        rx_line = value[bit_number];
        repeat (CLOCKS_PER_BIT) @(negedge clk);
    end
    rx_line = stop_bit;
    repeat (CLOCKS_PER_BIT) @(negedge clk);
    rx_line = 1'b1;
endtask

task expect_rx_frame(input logic[7:0] value);
    int count_before;

    count_before = rx_count;
    send_rx_frame(value, 1'b1);
    if (rx_count !== count_before + 1 || last_rx_data !== value)
        fail($sformatf("rx sent %h, received count %0d (expected %0d) data %h", value, rx_count, count_before + 1, last_rx_data));
endtask

// ---- transmitter tests: the testbench samples tx_line in the middle of every bit ----

task expect_level(input logic expected, input string message);
    if (tx_line !== expected || tx_busy !== 1'b1) fail($sformatf("tx %s: line %b busy %b, expected line %b busy 1", message, tx_line, tx_busy, expected));
endtask

task check_tx_frame(input logic[7:0] value, input bit poke_send);
    int extra;

    tx_data = value;
    send    = 1'b1;
    @(negedge clk);
    send = 1'b0;
    repeat (CLOCKS_PER_BIT / 2) @(negedge clk);
    expect_level(1'b0, "start bit");

    extra = 0;
    if (poke_send) begin
        send    = 1'b1;
        tx_data = 8'hFF;
        @(negedge clk);
        send  = 1'b0;
        extra = 1;
    end

    for (int bit_number = 0; bit_number < 8; bit_number++) begin
        repeat (CLOCKS_PER_BIT - extra) @(negedge clk);
        extra = 0;
        expect_level(value[bit_number], $sformatf("data bit %0d of %h", bit_number, value));
    end
    repeat (CLOCKS_PER_BIT) @(negedge clk);
    expect_level(1'b1, "stop bit");

    repeat (CLOCKS_PER_BIT / 2 + 3) @(negedge clk);
    if (tx_busy !== 1'b0 || tx_line !== 1'b1) fail($sformatf("tx not idle after frame %h", value));
endtask

// ---- loopback: tx output wired to rx input ----

task loopback_byte(input logic[7:0] value);
    int count_before, waited;

    while (loop_busy) @(negedge clk);
    count_before   = loop_count;
    loop_send_data = value;
    loop_send      = 1'b1;
    @(negedge clk);
    loop_send = 1'b0;
    waited    = 0;
    while (loop_count == count_before && waited < 20 * CLOCKS_PER_BIT) begin
        @(negedge clk);
        waited++;
    end
    if (loop_count !== count_before + 1 || last_loop_data !== value)
        fail($sformatf("loopback sent %h, received data %h count %0d (expected %0d)", value, last_loop_data, loop_count, count_before + 1));
endtask

task slow_loopback_byte(input logic[7:0] value);
    int count_before, waited;

    while (slow_busy) @(negedge clk);
    count_before   = slow_count;
    slow_send_data = value;
    slow_send      = 1'b1;
    @(negedge clk);
    slow_send = 1'b0;
    waited    = 0;
    while (slow_count == count_before && waited < 20 * SLOW_CLOCKS_PER_BIT) begin
        @(negedge clk);
        waited++;
    end
    if (slow_count !== count_before + 1 || last_slow_data !== value)
        fail($sformatf("slow loopback sent %h, received data %h count %0d (expected %0d)", value, last_slow_data, slow_count, count_before + 1));
endtask

initial begin
    #20000000;
    $display("FAIL: timeout at %0t", $time);
    $finish;
end

initial begin
    int count_before;

    errors = 0;
    rx_count = 0;  loop_count = 0;  slow_count = 0;
    reset = 1'b1;  rx_line = 1'b1;
    send = 1'b0;   loop_send = 1'b0;  slow_send = 1'b0;
    tx_data = 8'd0;  loop_send_data = 8'd0;  slow_send_data = 8'd0;
    repeat (5) @(negedge clk);
    reset = 1'b0;
    repeat (5) @(negedge clk);

    // receiver: edge-case bytes, then back-to-back frames with no idle time between them
    expect_rx_frame(8'h00);
    expect_rx_frame(8'hFF);
    expect_rx_frame(8'h55);
    expect_rx_frame(8'hAA);
    expect_rx_frame(8'h12);
    expect_rx_frame(8'h34);
    expect_rx_frame(8'h3F);
    repeat (50) expect_rx_frame($urandom_range(0, 255));

    // receiver: a short glitch on the line is not a start bit
    count_before = rx_count;
    rx_line = 1'b0;
    repeat (CLOCKS_PER_BIT / 4) @(negedge clk);
    rx_line = 1'b1;
    repeat (4 * CLOCKS_PER_BIT) @(negedge clk);
    if (rx_count !== count_before) fail("rx accepted a glitch as a frame");
    expect_rx_frame(8'h96);

    // receiver: a frame whose stop bit is low must be discarded
    count_before = rx_count;
    rx_line = 1'b0;
    repeat (CLOCKS_PER_BIT) @(negedge clk);
    for (int bit_number = 0; bit_number < 8; bit_number++) begin
        rx_line = 1'b1;
        repeat (CLOCKS_PER_BIT) @(negedge clk);
    end
    rx_line = 1'b0;
    repeat (CLOCKS_PER_BIT * 3 / 4) @(negedge clk);
    rx_line = 1'b1;
    repeat (4 * CLOCKS_PER_BIT) @(negedge clk);
    if (rx_count !== count_before) fail("rx accepted a frame with a low stop bit");
    expect_rx_frame(8'hC3);

    // transmitter: framing, bit order, busy, and send being ignored while busy
    check_tx_frame(8'h00, 1'b0);
    check_tx_frame(8'hFF, 1'b0);
    check_tx_frame(8'hA5, 1'b0);
    check_tx_frame(8'h5A, 1'b0);
    repeat (20) check_tx_frame($urandom_range(0, 255), 1'b0);
    check_tx_frame(8'h81, 1'b1);
    repeat (3 * CLOCKS_PER_BIT) @(negedge clk);
    if (tx_line !== 1'b1 || tx_busy !== 1'b0) fail("tx sent a second frame after a send pulse while busy");

    // loopback: every byte value
    for (int value = 0; value < 256; value++) loopback_byte(value);

    // loopback at the real baud rate (868 clocks per bit)
    slow_loopback_byte(8'h00);
    slow_loopback_byte(8'hA5);
    slow_loopback_byte(8'hFF);
    slow_loopback_byte(8'h3C);

    if (errors == 0) $display("PASS: uart");
    else             $display("FAIL: %0d errors", errors);
    $finish;
end

endmodule
