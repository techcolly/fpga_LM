// tb_roms.sv — checks every word of the three ROMs against the generated test pattern, plus the one-clock read latency.

module tb_roms;

logic           clk;
logic[8:0]      weight_address;
logic[3:0]      bias_address;
logic[5:0]      embed_address;
logic[63:0]     weight_data, embed_data;
logic[255:0]    bias_data;

int             errors;

weight_rom #(.INIT_FILE("test_weight_rom.mem")) weight_unit (.clk(clk), .address(weight_address), .data(weight_data));
bias_rom   #(.INIT_FILE("test_bias_rom.mem"))   bias_unit   (.clk(clk), .address(bias_address),   .data(bias_data));
embed_rom  #(.INIT_FILE("test_embed_rom.mem"))  embed_unit  (.clk(clk), .address(embed_address),  .data(embed_data));

initial clk = 1'b0;
always #5 clk = ~clk;

function logic[63:0] expected_weight_word(input int word);
    for (int byte_index = 0; byte_index < 8; byte_index++)
        expected_weight_word[8*byte_index +: 8] = (word + 37*byte_index) % 256;
endfunction

function logic[255:0] expected_bias_word(input int word);
    for (int bias_index = 0; bias_index < 8; bias_index++)
        expected_bias_word[32*bias_index +: 32] = word*100000 - 600000 + bias_index*1234;
endfunction

function logic[63:0] expected_embed_word(input int token);
    for (int byte_index = 0; byte_index < 8; byte_index++)
        expected_embed_word[8*byte_index +: 8] = (token*3 + 11*byte_index) % 256;
endfunction

task check_weight(input int word);
    if (weight_data !== expected_weight_word(word)) begin
        $display("FAIL weight_rom word %0d: got %h, expected %h", word, weight_data, expected_weight_word(word));
        errors++;
    end
endtask

task check_bias(input int word);
    if (bias_data !== expected_bias_word(word)) begin
        $display("FAIL bias_rom word %0d: got %h, expected %h", word, bias_data, expected_bias_word(word));
        errors++;
    end
endtask

task check_embed(input int token);
    if (embed_data !== expected_embed_word(token)) begin
        $display("FAIL embed_rom token %0d: got %h, expected %h", token, embed_data, expected_embed_word(token));
        errors++;
    end
endtask

initial begin
    logic[63:0]  previous_weight_data;
    int          random_address;

    errors         = 0;
    weight_address = 9'd0;
    bias_address   = 4'd0;
    embed_address  = 6'd0;
    @(negedge clk);

    // latency: changing the address does nothing until the clock edge, then the new word appears
    weight_address = 9'd5;
    @(negedge clk);
    check_weight(5);
    previous_weight_data = weight_data;
    weight_address = 9'd6;
    #1;
    if (weight_data !== previous_weight_data) begin
        $display("FAIL weight_rom latency: data changed before the clock edge");
        errors++;
    end
    @(negedge clk);
    check_weight(6);

    // every word, one read per clock
    for (int word = 0; word < 384; word++) begin
        weight_address = word;
        @(negedge clk);
        check_weight(word);
    end
    for (int word = 0; word < 12; word++) begin
        bias_address = word;
        @(negedge clk);
        check_bias(word);
    end
    for (int token = 0; token < 64; token++) begin
        embed_address = token;
        @(negedge clk);
        check_embed(token);
    end

    // random addresses, the way the FSM jumps between ROM words
    repeat (500) begin
        random_address = $urandom_range(0, 383);
        weight_address = random_address;
        @(negedge clk);
        check_weight(random_address);
    end

    if (errors == 0) $display("PASS: roms");
    else             $display("FAIL: %0d errors", errors);
    $finish;
end

endmodule
