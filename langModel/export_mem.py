"""Exports the trained TinyLM to the Vivado .mem files and golden test vectors.

Run from the repo root:   python -m langModel.export_mem [checkpoint.pt]
Needs only the Python standard library (it reads the checkpoint itself, no PyTorch).

Writes, in mem/ (formats are described in mem/README.md):
    weight_rom.mem   384 lines x 64 bits   (8 INT8 weights per line, lane 7 first)
    bias_rom.mem      12 lines x 256 bits  (8 INT32 biases per line, lane 7 first)
    embed_rom.mem     64 lines x 64 bits   (one token's 8 INT8 values per line)
    golden_vectors.mem   one 40-bit hex word per line: expected_token, t3, t2, t1, t0 (one byte each), from int_forward()

Before finishing it re-reads the written files and recomputes every logit in the
order the hardware uses (group, lane, input), and requires an exact match with
int_infer.int_forward for every training context plus random contexts.
"""

import pickle
import random
import sys
import zipfile
from array import array
from collections import OrderedDict
from pathlib import Path

# Lets this file run directly as well as via -m.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from langModel.corpus import SENTENCES
from langModel.int_infer import int_forward
from langModel.quantize import _quantize_matrix, _quantize_vector
from langModel.tokenizer import build_training_examples

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CHECKPOINT = Path(__file__).resolve().parent / "checkpoint.pt"
MEM_DIR = REPO_ROOT / "mem"

LANES = 8
INPUTS = 32
HIDDEN_GROUPS = 4
OUTPUT_GROUPS = 8
RANDOM_CONTEXTS_CHECKED = 3000
RANDOM_CONTEXTS_IN_GOLDEN_FILE = 300


# ---- reading the PyTorch checkpoint without PyTorch ----

class _Storage:
    def __init__(self, values):
        self.values = values


# Builds nested Python lists from a flat storage and the tensor's size.
def _rebuild_tensor(storage, offset, size, stride, *unused):
    expected_stride = []
    running = 1
    for dimension in reversed(size):
        expected_stride.insert(0, running)
        running *= dimension
    if tuple(stride) != tuple(expected_stride):
        raise ValueError(f"tensor is not contiguous (stride {stride}, expected {tuple(expected_stride)})")

    def build(position, dimension_index):
        if dimension_index == len(size) - 1:
            return [float(v) for v in storage.values[position:position + size[dimension_index]]]
        step = expected_stride[dimension_index]
        return [build(position + i * step, dimension_index + 1) for i in range(size[dimension_index])]

    return build(offset, 0)


class _CheckpointUnpickler(pickle.Unpickler):
    def __init__(self, file, archive, prefix):
        super().__init__(file)
        self.archive = archive
        self.prefix = prefix

    def find_class(self, module, name):
        if name == "_rebuild_tensor_v2":
            return _rebuild_tensor
        if name.endswith("Storage"):
            return name
        if module == "collections" and name == "OrderedDict":
            return OrderedDict
        return super().find_class(module, name)

    def persistent_load(self, persistent_id):
        _, storage_type, key, _, _ = persistent_id
        if storage_type != "FloatStorage":
            raise ValueError(f"unsupported checkpoint storage type {storage_type}")
        values = array("f")
        values.frombytes(self.archive.read(f"{self.prefix}/data/{key}"))
        if sys.byteorder != "little":
            values.byteswap()
        return _Storage(values)


# path -> {"embedding.weight": nested lists, "fc1.weight": ..., ...} of plain floats.
def load_state_dict(path):
    archive = zipfile.ZipFile(path)
    pickle_name = [name for name in archive.namelist() if name.endswith("data.pkl")][0]
    prefix = pickle_name.rsplit("/", 1)[0]
    with archive.open(pickle_name) as pickle_file:
        return _CheckpointUnpickler(pickle_file, archive, prefix).load()


# ---- quantizing and writing the files ----

# state dict -> the same dict of INT lists that quantize.quantize_model() returns.
def quantize_state_dict(state):
    return {
        "embedding": _quantize_matrix(state["embedding.weight"]),
        "W1": _quantize_matrix(state["fc1.weight"]),
        "b1": _quantize_vector(state["fc1.bias"]),
        "W2": _quantize_matrix(state["fc2.weight"]),
        "b2": _quantize_vector(state["fc2.bias"]),
    }


# values: 8 ints, lane 0 first. Returns hex text with the highest lane first.
def pack_word(values, bits):
    mask = (1 << bits) - 1
    digits = bits // 4
    return "".join(f"{v & mask:0{digits}x}" for v in reversed(values))


def weight_lines(params):
    lines = []
    for matrix, groups in ((params["W1"], HIDDEN_GROUPS), (params["W2"], OUTPUT_GROUPS)):
        for group in range(groups):
            for input_index in range(INPUTS):
                lines.append(pack_word([matrix[LANES * group + lane][input_index] for lane in range(LANES)], 8))
    return lines


def bias_lines(params):
    lines = []
    for vector, groups in ((params["b1"], HIDDEN_GROUPS), (params["b2"], OUTPUT_GROUPS)):
        for group in range(groups):
            lines.append(pack_word(vector[LANES * group:LANES * group + LANES], 32))
    return lines


def embed_lines(params):
    return [pack_word(row, 8) for row in params["embedding"]]


def write_lines(path, lines):
    path.write_text("\n".join(lines) + "\n")


# ---- checking the files against the reference, in hardware order ----

def _signed(value, bits):
    return value - (1 << bits) if value >= 1 << (bits - 1) else value


def _read_words(path):
    return [int(line, 16) for line in path.read_text().split()]


# Recomputes the 64 logits from the .mem files exactly as the FSM does: embed words,
# then 4 hidden groups and 8 output groups, 32 inputs each, 8 lanes in parallel.
def hardware_order_logits(context, weight_words, bias_words, embed_words):
    inputs = []
    for token in context:
        inputs.extend(_signed((embed_words[token] >> (8 * k)) & 0xFF, 8) for k in range(LANES))

    def run_group(group_word_base, bias_word, activations):
        accumulators = [_signed((bias_word >> (32 * lane)) & 0xFFFFFFFF, 32) for lane in range(LANES)]
        for input_index in range(INPUTS):
            word = weight_words[group_word_base + input_index]
            for lane in range(LANES):
                weight = _signed((word >> (8 * lane)) & 0xFF, 8)
                accumulators[lane] += activations[input_index] * weight
        return accumulators

    hidden = []
    for group in range(HIDDEN_GROUPS):
        accumulators = run_group(group * INPUTS, bias_words[group], inputs)
        for accumulator in accumulators:
            assert -(2 ** 31) <= accumulator < 2 ** 31, "hidden accumulator would overflow INT32"
            relu = max(accumulator, 0)
            hidden.append(min(relu >> 4, 127))

    logits = []
    for group in range(OUTPUT_GROUPS):
        accumulators = run_group(128 + group * INPUTS, bias_words[4 + group], hidden)
        for accumulator in accumulators:
            assert -(2 ** 31) <= accumulator < 2 ** 31, "output accumulator would overflow INT32"
        logits.extend(accumulators)
    return logits


def lowest_index_of_maximum(values):
    return values.index(max(values))


def verify_files(params, contexts):
    weight_words = _read_words(MEM_DIR / "weight_rom.mem")
    bias_words = _read_words(MEM_DIR / "bias_rom.mem")
    embed_words = _read_words(MEM_DIR / "embed_rom.mem")
    assert (len(weight_words), len(bias_words), len(embed_words)) == (384, 12, 64), "wrong number of .mem lines"

    for context in contexts:
        reference_logits, reference_token = int_forward(list(context), params)
        logits = hardware_order_logits(context, weight_words, bias_words, embed_words)
        assert logits == reference_logits, f"logits differ from int_forward for context {context}"
        assert lowest_index_of_maximum(logits) == reference_token, f"token differs for context {context}"


def main():
    checkpoint = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_CHECKPOINT
    print(f"reading {checkpoint}")
    state = load_state_dict(checkpoint)
    expected_shapes = {"embedding.weight": (64, 8), "fc1.weight": (32, 32), "fc1.bias": (32,),
                       "fc2.weight": (64, 32), "fc2.bias": (64,)}
    for name, shape in expected_shapes.items():
        got = (len(state[name]),) + ((len(state[name][0]),) if isinstance(state[name][0], list) else ())
        assert got == shape, f"{name} has shape {got}, expected {shape}"

    params = quantize_state_dict(state)

    MEM_DIR.mkdir(exist_ok=True)
    write_lines(MEM_DIR / "weight_rom.mem", weight_lines(params))
    write_lines(MEM_DIR / "bias_rom.mem", bias_lines(params))
    write_lines(MEM_DIR / "embed_rom.mem", embed_lines(params))

    training_contexts = sorted({tuple(context) for context, _ in build_training_examples(SENTENCES)})
    generator = random.Random(2026)
    random_contexts = [tuple(generator.randrange(64) for _ in range(4)) for _ in range(RANDOM_CONTEXTS_CHECKED)]

    verify_files(params, training_contexts + random_contexts)
    print(f"verified: hardware-order logits match int_forward exactly for "
          f"{len(training_contexts)} training contexts and {len(random_contexts)} random contexts")

    golden_contexts = training_contexts + random_contexts[:RANDOM_CONTEXTS_IN_GOLDEN_FILE]
    golden = []
    for context in golden_contexts:
        _, token = int_forward(list(context), params)
        golden.append(f"{token:02x}" + "".join(f"{t:02x}" for t in reversed(context)))
    write_lines(MEM_DIR / "golden_vectors.mem", golden)

    print(f"wrote {MEM_DIR / 'weight_rom.mem'} (384 lines)")
    print(f"wrote {MEM_DIR / 'bias_rom.mem'} (12 lines)")
    print(f"wrote {MEM_DIR / 'embed_rom.mem'} (64 lines)")
    print(f"wrote {MEM_DIR / 'golden_vectors.mem'} ({len(golden)} vectors)")


if __name__ == "__main__":
    main()
