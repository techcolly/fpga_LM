// tb_mac_lane.sv — directed and random checks of the signed multiply-accumulate lane against an int reference.

module tb_mac_lane;

logic               clk, load_bias, accumulate_en;
logic signed[7:0]   activation, weight;
logic signed[31:0]  bias;
logic signed[31:0]  accumulator;

int                 expected_value, errors;

mac_lane dut (.*);

initial clk = 1'b0;
always #5 clk = ~clk;

task check(input string message);
    if (accumulator !== expected_value) begin
        $display("FAIL %s: accumulator is %0d, expected %0d", message, accumulator, expected_value);
        errors++;
    end
endtask

task load(input int bias_value);
    bias           = bias_value;
    load_bias      = 1'b1;
    accumulate_en  = 1'b0;
    @(negedge clk);
    load_bias      = 1'b0;
    expected_value = bias_value;
    check($sformatf("load %0d", bias_value));
endtask

task accumulate(input int activation_value, input int weight_value);
    activation     = activation_value;
    weight         = weight_value;
    accumulate_en  = 1'b1;
    @(negedge clk);
    accumulate_en  = 1'b0;
    expected_value = expected_value + activation_value * weight_value;
    check($sformatf("activation=%0d weight=%0d", activation_value, weight_value));
endtask

task idle_cycle(input int activation_value, input int weight_value);
    activation     = activation_value;
    weight         = weight_value;
    accumulate_en  = 1'b0;
    @(negedge clk);
    check("hold when accumulate_en is low");
endtask

initial begin
    errors        = 0;
    load_bias     = 1'b0;
    accumulate_en = 1'b0;
    activation    = 8'sd0;
    weight        = 8'sd0;
    bias          = 32'sd0;
    @(negedge clk);

    // worked example from nn_math_walkthrough: bias 100, activations = [10,-3,7,2], weights = [5,4,-2,9] -> 142
    load(100);
    accumulate(10, 5);
    accumulate(-3, 4);
    accumulate(7, -2);
    accumulate(2, 9);
    if (accumulator !== 32'sd142) begin
        $display("FAIL worked example: accumulator is %0d, expected 142", accumulator);
        errors++;
    end

    // negative result: bias -300 -> -258
    load(-300);
    accumulate(10, 5);
    accumulate(-3, 4);
    accumulate(7, -2);
    accumulate(2, 9);
    if (accumulator !== -32'sd258) begin
        $display("FAIL negative example: accumulator is %0d, expected -258", accumulator);
        errors++;
    end

    // INT8 extremes
    load(0);
    accumulate(-128, -128);
    accumulate(-128, 127);
    accumulate(127, 127);
    accumulate(127, -128);
    accumulate(-1, -1);
    accumulate(-1, 1);

    // inputs are ignored while accumulate_en is low
    load(1000);
    idle_cycle(100, 100);
    idle_cycle(-100, 55);

    // load_bias wins if both controls are high
    bias          = 32'sd77;
    load_bias     = 1'b1;
    accumulate_en = 1'b1;
    activation    = 8'sd9;
    weight        = 8'sd9;
    @(negedge clk);
    load_bias      = 1'b0;
    accumulate_en  = 1'b0;
    expected_value = 77;
    check("load_bias priority over accumulate_en");

    // worst case sum of 32 products: 32 * (-128 * -128) = 524288
    load(0);
    repeat (32) accumulate(-128, -128);
    if (accumulator !== 32'sd524288) begin
        $display("FAIL worst case: accumulator is %0d, expected 524288", accumulator);
        errors++;
    end

    // random groups of 32 steps with random biases
    repeat (50) begin
        load($urandom_range(0, 2000000) - 1000000);
        repeat (32) accumulate($urandom_range(0, 255) - 128, $urandom_range(0, 255) - 128);
    end

    if (errors == 0) $display("PASS: mac_lane");
    else             $display("FAIL: %0d errors", errors);
    $finish;
end

endmodule
