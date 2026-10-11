// tb_mac_array.sv — checks lane-to-slice mapping, lane isolation, and 8 independent dot products against int references.

module tb_mac_array;

logic               clk, load_bias, accumulate_en;
logic signed[7:0]   activation;
logic[63:0]         weight_word;
logic[255:0]        bias_word;
logic[255:0]        accumulator_word;

int                 bias_values[8], weight_values[8], expected_accumulator[8];
int                 errors;

mac_array dut (.*);

initial clk = 1'b0;
always #5 clk = ~clk;

task check(input string message);
    int actual_value;

    for (int lane = 0; lane < 8; lane++) begin
        actual_value = $signed(accumulator_word[32*lane +: 32]);
        if (actual_value !== expected_accumulator[lane]) begin
            $display("FAIL %s: lane %0d accumulator is %0d, expected %0d", message, lane, actual_value, expected_accumulator[lane]);
            errors++;
        end
    end
endtask

task load_biases(input string message);
    for (int lane = 0; lane < 8; lane++) begin
        bias_word[32*lane +: 32]     = bias_values[lane];
        expected_accumulator[lane]   = bias_values[lane];
    end
    load_bias     = 1'b1;
    accumulate_en = 1'b0;
    @(negedge clk);
    load_bias     = 1'b0;
    check(message);
endtask

task accumulate_step(input int activation_value, input string message);
    activation = activation_value;
    for (int lane = 0; lane < 8; lane++) begin
        weight_word[8*lane +: 8]   = weight_values[lane];
        expected_accumulator[lane] = expected_accumulator[lane] + activation_value * weight_values[lane];
    end
    accumulate_en = 1'b1;
    @(negedge clk);
    accumulate_en = 1'b0;
    check(message);
endtask

task hold_step(input string message);
    activation = 8'sd100;
    weight_word = 64'h7F7F7F7F7F7F7F7F;
    accumulate_en = 1'b0;
    @(negedge clk);
    check(message);
endtask

initial begin
    errors        = 0;
    load_bias     = 1'b0;
    accumulate_en = 1'b0;
    activation    = 8'sd0;
    weight_word   = 64'd0;
    bias_word     = 256'd0;
    @(negedge clk);

    // lane mapping: lane i gets bias (i+1)*100 and weight i+1, so lane i must end at (i+1)*100 + 3*(i+1)
    for (int lane = 0; lane < 8; lane++) begin
        bias_values[lane]   = (lane + 1) * 100;
        weight_values[lane] = lane + 1;
    end
    load_biases("mapping: load");
    accumulate_step(3, "mapping: one step");

    // lane isolation: only lane 3 has a nonzero weight, so only lane 3 may change
    for (int lane = 0; lane < 8; lane++) begin
        bias_values[lane]   = 0;
        weight_values[lane] = (lane == 3) ? 5 : 0;
    end
    load_biases("isolation: load");
    accumulate_step(7, "isolation: step");

    // negative weights and activation, mixed across lanes
    for (int lane = 0; lane < 8; lane++) begin
        bias_values[lane]   = (lane % 2 == 0) ? -1000 : 1000;
        weight_values[lane] = (lane % 2 == 0) ? -128 : 127;
    end
    load_biases("mixed signs: load");
    accumulate_step(-128, "mixed signs: step 1");
    accumulate_step(127,  "mixed signs: step 2");

    // shared control: nothing changes while accumulate_en is low
    hold_step("hold");

    // random: 50 groups of 32 steps, eight independent dot products at a time
    repeat (50) begin
        for (int lane = 0; lane < 8; lane++) bias_values[lane] = $urandom_range(0, 2000000) - 1000000;
        load_biases("random: load");
        repeat (32) begin
            for (int lane = 0; lane < 8; lane++) weight_values[lane] = $urandom_range(0, 255) - 128;
            accumulate_step($urandom_range(0, 255) - 128, "random: step");
        end
    end

    if (errors == 0) $display("PASS: mac_array");
    else             $display("FAIL: %0d errors", errors);
    $finish;
end

endmodule
