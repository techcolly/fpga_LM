# .mem file format

The FPGA loads three memory files with `$readmemh`. Put them in this folder with exactly these names:

| File | Words | Hex digits per line | Word contents |
|---|---|---|---|
| `weight_rom.mem` | 384 | 16 (64 bits) | 8 INT8 weights, one per MAC lane |
| `bias_rom.mem` | 12 | 64 (256 bits) | 8 INT32 biases, one per MAC lane |
| `embed_rom.mem` | 64 | 16 (64 bits) | the 8 INT8 embedding values of one token |

## Rules for every file

- Plain text, one word per line, hexadecimal, no `0x` prefix, no spaces.
- The first line is address 0.
- Values are two's complement. A negative INT8 such as -3 is written `fd`; a negative INT32 such as -300 is written `fffffed4`.
- Within a line, the **highest-numbered lane is written first** and lane 0 last, so lane 0 is the rightmost byte (or rightmost 8 hex digits for the bias file).

## Quantization

- Embeddings and weights: `round(16 * real_value)`, clamped to [-128, 127].
- Biases: `round(256 * real_value)`, stored as INT32 (no clamping needed).

## `weight_rom.mem` layout (384 lines)

Each line is the 8 weights that the 8 lanes multiply by the same input in one step. For output group `g` and input index `j`, lane `k` holds `W[8*g + k][j]` (row = output neuron, column = input).

- Lines 0 to 127: hidden layer `W1` (32 x 32). Line number = `g * 32 + j`, with `g` in 0..3 and `j` in 0..31.
- Lines 128 to 383: output layer `W2` (64 x 32). Line number = `128 + g * 32 + j`, with `g` in 0..7 and `j` in 0..31.

## `bias_rom.mem` layout (12 lines)

Line `g` holds the 8 biases of output group `g`: lane `k` holds `b[8*g + k]`.

- Lines 0 to 3: hidden layer `b1` (32 values).
- Lines 4 to 11: output layer `b2` (64 values), line number = `4 + g`.

## `embed_rom.mem` layout (64 lines)

Line `t` is the embedding of token ID `t`. Embedding element 0 is the rightmost byte.

The FPGA builds the 32-value input by taking the embeddings of the four context tokens in order (oldest token first, element 0 of each first), so nothing about the concatenation order needs to be baked into the file.

## Python helper

```python
def pack_word(values, bits):
    mask = (1 << bits) - 1
    digits = bits // 4
    return "".join(f"{v & mask:0{digits}x}" for v in reversed(values))

lines = []
for g in range(4):                                   # hidden layer, W1[row][column]
    for j in range(32):
        lines.append(pack_word([W1[8*g + k][j] for k in range(8)], 8))
for g in range(8):                                   # output layer, W2[row][column]
    for j in range(32):
        lines.append(pack_word([W2[8*g + k][j] for k in range(8)], 8))
open("weight_rom.mem", "w").write("\n".join(lines) + "\n")

lines = [pack_word(b1[8*g:8*g + 8], 32) for g in range(4)]
lines += [pack_word(b2[8*g:8*g + 8], 32) for g in range(8)]
open("bias_rom.mem", "w").write("\n".join(lines) + "\n")

lines = [pack_word(E[t], 8) for t in range(64)]      # E[token][element]
open("embed_rom.mem", "w").write("\n".join(lines) + "\n")
```

`W1`, `W2`, `b1`, `b2` and `E` must already be the quantized integer values (Python `int`).

## Generating these files

Run `python -m langModel.export_mem` from the repo root. It reads `langModel/checkpoint.pt` (or a path given on the command line), writes the three files above, and checks them against `langModel/int_infer.py` before finishing. It also writes `golden_vectors.mem`.

## `golden_vectors.mem`

One 40-bit hex word per line, written by the export script and used only by the simulation testbench `tb_fpga_golden`. Bytes from left to right: the expected next token, then `t3`, `t2`, `t1` and `t0`, where `t0` is the oldest context token. The expected token comes from `int_forward`.

## Test files

`test_weight_rom.mem`, `test_bias_rom.mem` and `test_embed_rom.mem` hold made-up patterns that only the simulation testbench uses. Do not overwrite or delete them, and do not name real files with the `test_` prefix.
