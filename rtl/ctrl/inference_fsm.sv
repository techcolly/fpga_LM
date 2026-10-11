// inference_fsm.sv — sequences one forward pass: embed, hidden layer, output layer, argmax, done.

module inference_fsm (
    input   logic clk, reset, start,

    output  logic input_vector_we, load_bias, accumulate_en, hidden_we, compare_en, argmax_clear, done,
            logic output_layer,
            logic[1:0] token_index,
            logic[2:0] group_index, lane_index,
            logic[3:0] bias_address, state,
            logic[4:0] input_index,
            logic[8:0] weight_address
);

localparam logic[3:0] IDLE         = 4'd0;
localparam logic[3:0] EMBED_READ   = 4'd1;
localparam logic[3:0] EMBED_STORE  = 4'd2;
localparam logic[3:0] BIAS_READ    = 4'd3;
localparam logic[3:0] BIAS_LOAD    = 4'd4;
localparam logic[3:0] WEIGHT_READ  = 4'd5;
localparam logic[3:0] ACCUMULATE   = 4'd6;
localparam logic[3:0] HIDDEN_STORE = 4'd7;
localparam logic[3:0] ARGMAX       = 4'd8;
localparam logic[3:0] DONE         = 4'd9;
localparam logic[3:0] DRAIN        = 4'd10;

logic[3:0] next_state;
logic      token_last, input_last, hidden_group_last, output_group_last, lane_last;

assign token_last        = (token_index == 2'd3);
assign input_last        = (input_index == 5'd31);
assign hidden_group_last = (group_index == 3'd3);
assign output_group_last = (group_index == 3'd7);
assign lane_last         = (lane_index  == 3'd7);

always_ff @(posedge clk) begin
    if (reset) state <= IDLE;
    else       state <= next_state;
end

always_comb begin
    case (state)
        IDLE: begin
            if (start) next_state = EMBED_READ;
            else       next_state = IDLE;
        end
        EMBED_READ: next_state = EMBED_STORE;
        EMBED_STORE: begin
            if (token_last) next_state = BIAS_READ;
            else            next_state = EMBED_READ;
        end
        BIAS_READ:   next_state = BIAS_LOAD;
        BIAS_LOAD:   next_state = WEIGHT_READ;
        WEIGHT_READ: next_state = ACCUMULATE;
        ACCUMULATE: begin
            if (!input_last) next_state = WEIGHT_READ;
            else             next_state = DRAIN;
        end
        DRAIN: begin
            if (output_layer) next_state = ARGMAX;
            else              next_state = HIDDEN_STORE;
        end
        HIDDEN_STORE: next_state = BIAS_READ;
        ARGMAX: begin
            if (!lane_last)              next_state = ARGMAX;
            else if (output_group_last)  next_state = DONE;
            else                         next_state = BIAS_READ;
        end
        DONE:    next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

assign input_vector_we = (state == EMBED_STORE);
assign load_bias       = (state == BIAS_LOAD);
assign accumulate_en   = (state == ACCUMULATE);
assign hidden_we       = (state == HIDDEN_STORE);
assign compare_en      = (state == ARGMAX);
assign argmax_clear    = (state == IDLE);
assign done            = (state == DONE);

always_ff @(posedge clk) begin
    if (reset || state == IDLE) begin
        token_index    <= 2'd0;
        group_index    <= 3'd0;
        lane_index     <= 3'd0;
        input_index    <= 5'd0;
        weight_address <= 9'd0;
        bias_address   <= 4'd0;
        output_layer   <= 1'b0;
    end else begin
        case (state)
            EMBED_STORE: if (!token_last) token_index <= token_index + 2'd1;
            BIAS_LOAD:   bias_address <= bias_address + 4'd1;
            ACCUMULATE: begin
                weight_address <= weight_address + 9'd1;
                input_index    <= input_index + 5'd1;
            end
            HIDDEN_STORE: begin
                if (hidden_group_last) begin
                    output_layer <= 1'b1;
                    group_index  <= 3'd0;
                end else begin
                    group_index  <= group_index + 3'd1;
                end
            end
            ARGMAX: begin
                lane_index <= lane_index + 3'd1;
                if (lane_last && !output_group_last) group_index <= group_index + 3'd1;
            end
            default: ;
        endcase
    end
end

endmodule
