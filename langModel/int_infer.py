"""Bit-accurate integer-only inference: no floats anywhere in this file.

This is the Python reference for the FPGA's arithmetic -- INT8 operands,
INT32 accumulation, matching the quantization scheme in quantize.py.
Anything the FPGA computes should match this function exactly.
"""

from langModel.tokenizer import CONTEXT_SIZE
from langModel.vocab import BOS_ID, EOS_ID, PAD_ID

INT32_MIN, INT32_MAX = -(2 ** 31), 2 ** 31 - 1
SHIFT = 4  # log2(WEIGHT_SCALE) from quantize.py -- undoes one scale-16 factor


def _saturate_int32(value):
    return max(INT32_MIN, min(INT32_MAX, value))


def _dot_int(weights_row, inputs):
    return sum(w * x for w, x in zip(weights_row, inputs))


# Picks the index of the largest value, lowest index wins on a tie --
# this tie-break rule must match whatever the FPGA's comparator chain does,
# so it's a shared-interface detail to confirm with the hardware side.
def _argmax(values):
    best_idx = 0
    best_val = values[0]
    for i, v in enumerate(values[1:], start=1):
        if v > best_val:
            best_val = v
            best_idx = i
    return best_idx


# context_ids: list of 4 token ids. params: the dict from quantize_model().
# Returns (logits, predicted_token_id), logits as plain INT32 ints.
def int_forward(context_ids, params):
    embedding, W1, b1, W2, b2 = (
        params["embedding"], params["W1"], params["b1"], params["W2"], params["b2"]
    )

    x = []
    for token_id in context_ids:
        x.extend(embedding[token_id])  # concat 4 x INT8[8] -> INT8[32]

    z1 = [_saturate_int32(_dot_int(W1[n], x) + b1[n]) for n in range(len(W1))]
    h = [max(0, min(127, z >> SHIFT)) for z in z1]  # ReLU, then >>4, then clamp [0,127]

    z2 = [_saturate_int32(_dot_int(W2[n], h) + b2[n]) for n in range(len(W2))]

    predicted_id = _argmax(z2)
    return z2, predicted_id


# Autoregressive generation using ONLY the integer path -- the same loop
# shape as train.generate(), but every number involved is a plain int.
def generate_int(params, prompt_ids=(), max_len=12):
    ids = [PAD_ID] * (CONTEXT_SIZE - 1) + [BOS_ID] + list(prompt_ids)
    generated = []
    for _ in range(max_len):
        context = ids[-CONTEXT_SIZE:]
        _, next_id = int_forward(context, params)
        if next_id == EOS_ID:
            break
        ids.append(next_id)
        generated.append(next_id)
    return generated
