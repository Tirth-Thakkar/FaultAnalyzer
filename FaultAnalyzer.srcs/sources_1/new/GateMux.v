// Gate-level multiplexer module
// This module is written using only primitive gate instantiations.
// It uses a one-hot decode of the select lines, then gates each input
// to the output using AND and OR primitives.
module GateMux #(
    parameter integer WIDTH_INPUT = 2,  // number of selectable input words
    parameter integer WIDTH_OUTPUT = 1,  // width of each input word and the output
    localparam integer SEL_WIDTH = (WIDTH_INPUT > 1) ? $clog2(WIDTH_INPUT) : 1
) (
    input  wire [WIDTH_INPUT*WIDTH_OUTPUT-1:0] data,  // flattened data inputs
    input  wire [               SEL_WIDTH-1:0] sel,   // select index
    output wire [            WIDTH_OUTPUT-1:0] out    // selected output word
);

  // One-hot decoded select lines. Only one entry is true at a time.
  wire [WIDTH_INPUT-1:0] sel_onehot;

  genvar i, j;
  generate
    for (i = 0; i < WIDTH_INPUT; i = i + 1) begin : gen_decoder
      wire [SEL_WIDTH-1:0] sel_match;
      wire [SEL_WIDTH-1:0] sel_inv;

      // Invert select bits once, then choose the inverted or direct
      // version according to the current input index bits.
      for (j = 0; j < SEL_WIDTH; j = j + 1) begin : gen_select_bits
        not not_gate (sel_inv[j], sel[j]);
        if (i[j]) begin
          buf buf_match (sel_match[j], sel[j]);
        end else begin
          buf buf_match (sel_match[j], sel_inv[j]);
        end
      end

      // Combine all matched select bits for this index with a chain of ANDs.
      if (SEL_WIDTH == 1) begin
        buf buf_decode (sel_onehot[i], sel_match[0]);
      end else begin
        wire [SEL_WIDTH-2:0] and_chain;

        and and_first (and_chain[0], sel_match[0], sel_match[1]);
        for (j = 2; j < SEL_WIDTH; j = j + 1) begin : gen_and_chain
          and and_next (and_chain[j-1], and_chain[j-2], sel_match[j]);
        end
        buf buf_decode (sel_onehot[i], and_chain[SEL_WIDTH-2]);
      end
    end
  endgenerate

  generate
    for (j = 0; j < WIDTH_OUTPUT; j = j + 1) begin : gen_output_bits
      wire [WIDTH_INPUT-1:0] gated_inputs;

      // Gate each input bit with its one-hot select line.
      for (i = 0; i < WIDTH_INPUT; i = i + 1) begin : gen_input_gates
        and and_input (gated_inputs[i], data[i*WIDTH_OUTPUT+j], sel_onehot[i]);
      end

      // OR all gated inputs together to produce the output bit.
      if (WIDTH_INPUT == 1) begin
        buf buf_out (out[j], gated_inputs[0]);
      end else begin
        wire [WIDTH_INPUT-2:0] or_chain;

        or or_first (or_chain[0], gated_inputs[0], gated_inputs[1]);
        for (i = 2; i < WIDTH_INPUT; i = i + 1) begin : gen_or_chain
          or or_next (or_chain[i-1], or_chain[i-2], gated_inputs[i]);
        end
        buf buf_out (out[j], or_chain[WIDTH_INPUT-2]);
      end
    end
  endgenerate

endmodule
