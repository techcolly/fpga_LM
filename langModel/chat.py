"""Interactive prompt loop using the integer-only reference model.

Type a phrase or question ("soil dry what ?"); the model continues it.
Later, replace `reply` with a version that sends token ids over UART.
"""

import sys
from pathlib import Path

# Lets this file run directly (e.g. the editor's Run button) as well as via -m.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import torch

from langModel.int_infer import generate_int
from langModel.model import TinyLM
from langModel.quantize import quantize_model
from langModel.tokenizer import decode_ids, encode_word
from langModel.vocab import STOI, UNK_ID


def load_params(path=Path(__file__).resolve().parent / "checkpoint.pt"):
    model = TinyLM()
    model.load_state_dict(torch.load(path))
    model.eval()
    return quantize_model(model)


# Splits "?" into its own token so "what?" and "what ?" both work.
# Also adds the "?" the model expects if a how/what question omits it.
def tokenize(text):
    tokens = text.lower().replace("?", " ? ").split()
    is_question = tokens and (tokens[0] in ("how", "what") or tokens[-1] == "what")
    if is_question and "?" not in tokens:
        tokens.append("?")
    return tokens


def reply(params, text):
    words = tokenize(text)
    unknown = [w for w in words if STOI.get(w, UNK_ID) == UNK_ID]
    ids = [encode_word(w) for w in words]
    answer = " ".join(decode_ids(generate_int(params, ids)))
    return answer, unknown


if __name__ == "__main__":
    params = load_params()
    while True:
        try:
            text = input("you> ").strip()
        except EOFError:
            break
        if text.lower() in ("quit", "exit"):
            break
        if not text:
            continue
        answer, unknown = reply(params, text)
        if unknown:
            print(f"  (not in vocab, treated as <unk>: {unknown})")
        print("model>", answer if answer else "(no reply)")
