"""Converts a trained float TinyLM into the INT8/INT32 arrays the FPGA uses.

Fixed-point scheme (see project spec):
    embeddings, W1, W2  -> round(16 * value), clamped to INT8  [-128, 127]
    b1, b2              -> round(256 * value), INT32
                           (256 = 16*16, matching the scale a product of two
                           scale-16 operands naturally lands at)
"""

WEIGHT_SCALE = 16
BIAS_SCALE = WEIGHT_SCALE * WEIGHT_SCALE  # 256

INT8_MIN, INT8_MAX = -128, 127


def _quantize_weight(value):
    q = round(WEIGHT_SCALE * value)
    return max(INT8_MIN, min(INT8_MAX, q))


def _quantize_bias(value):
    return round(BIAS_SCALE * value)


# matrix: list of rows (list of float) -> list of rows (list of INT8)
def _quantize_matrix(matrix):
    return [[_quantize_weight(v) for v in row] for row in matrix]


def _quantize_vector(vector):
    return [_quantize_bias(v) for v in vector]


# model: a trained TinyLM (langModel.model.TinyLM) -> dict of plain python
# int lists, ready for both the integer reference (int_infer.py) and for
# exporting to Vivado .mem files later.
def quantize_model(model):
    return {
        "embedding": _quantize_matrix(model.embedding.weight.tolist()),  # 64x8 INT8
        "W1": _quantize_matrix(model.fc1.weight.tolist()),               # 32x32 INT8
        "b1": _quantize_vector(model.fc1.bias.tolist()),                 # 32 INT32
        "W2": _quantize_matrix(model.fc2.weight.tolist()),               # 64x32 INT8
        "b2": _quantize_vector(model.fc2.bias.tolist()),                 # 64 INT32
    }
