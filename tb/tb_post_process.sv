// tb_post_process.sv — checks ReLU, shift right 4 and clamp to 127 on all 8 lanes against an int reference, including the boundaries.

module tb_post_process;

logic[255:0]    accumulator_word;
logic[63:0]     hidden_word;

int             accumulator_values[8];
int             errors;

post_process dut (.*);

function int expected_hidden(input int value);
    int shifted;

    if (value < 0) return 0;
    shifted = value >>> 4;
    if (shifted > 127) return 127;
    return shifted;
endfunction

task apply_and_check(input string message);
    int actual_value;

    for (int lane = 0; lane < 8; lane++) accumulator_word[32*lane +: 32] = accumulator_values[lane];
    #1;
    for (int lane = 0; lane < 8; lane++) begin
        actual_value = hidden_word[8*lane +: 8];
        if (actual_value !== expected_hidden(accumulator_values[lane])) begin
            $display("FAIL %s: lane %0d accumulator %0d gave %0d, expected %0d",
                     message, lane, accumulator_values[lane], actual_value, expected_hidden(accumulator_values[lane]));
            errors++;
        end
    end
endtask

task apply_same_value(input int value);
    for (int lane = 0; lane < 8; lane++) accumulator_values[lane] = value;
    apply_and_check($sformatf("value %0d on every lane", value));
endtask

initial begin
    int directed[16];

    errors = 0;

    directed = '{0, 1, 15, 16, 17, 142, 2031, 2032, 2047, 2048, 3000, 2147483647,
                 -1, -258, -2048, 32'sh80000000};

    // each boundary value on all lanes at once
    foreach (directed[index]) apply_same_value(directed[index]);

    // the same values spread across lanes, to show the lanes are independent
    for (int base = 0; base < 16; base += 8) begin
        for (int lane = 0; lane < 8; lane++) accumulator_values[lane] = directed[base + lane];
        apply_and_check("directed values across lanes");
    end

    // the exact edges: 15 -> 0, 16 -> 1, 2031 -> 126, 2032 -> 127, 2047 -> 127, 2048 -> 127
    if (expected_hidden(15) !== 0 || expected_hidden(16) !== 1 || expected_hidden(2031) !== 126 ||
        expected_hidden(2032) !== 127 || expected_hidden(2047) !== 127 || expected_hidden(2048) !== 127) begin
        $display("FAIL: reference model edges are wrong");
        errors++;
    end

    // random words: half full-range 32-bit values, half values near the useful range
    repeat (2000) begin
        for (int lane = 0; lane < 8; lane++) begin
            if ($urandom_range(0, 1) == 0) accumulator_values[lane] = $urandom;
            else                           accumulator_values[lane] = $urandom_range(0, 5000) - 500;
        end
        apply_and_check("random");
    end

    if (errors == 0) $display("PASS: post_process");
    else             $display("FAIL: %0d errors", errors);
    $finish;
end

endmodule
