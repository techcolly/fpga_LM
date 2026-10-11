"""Interactive prompt loop using the integer-only reference model.

Type a phrase or question ("soil is dry", "how is the plant"); the model
continues it. Later, replace the generate_int call in `reply` with a version
that sends token ids over UART.
"""

import difflib
import sys
from pathlib import Path

# Lets this file run directly (e.g. the editor's Run button) as well as via -m.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import torch

from langModel.int_infer import generate_int
from langModel.model import TinyLM
from langModel.quantize import quantize_model
from langModel.tokenizer import decode_ids, encode_word
from langModel.vocab import PLANT_PARTS, SENSOR_NOUNS, STOI, VOCAB

SUBJECTS = set(PLANT_PARTS + SENSOR_NOUNS)
KNOWN_WORDS = VOCAB[4:]  # everything except the special tokens


def load_params(path=Path(__file__).resolve().parent / "checkpoint.pt"):
    model = TinyLM()
    model.load_state_dict(torch.load(path))
    model.eval()
    return quantize_model(model)


# Turns what a person types into the shapes the model was trained on:
#   "how is the plant"   -> adds the "?" the model expects
#   "soil dry what ?"    -> "soil dry" (a trailing "what ?" is just a question mark)
#   "please water the plant" / "water the plant please" -> "water the plant"
#   "soil"               -> "soil ?" (a lone part/sensor word means "how is it?")
def normalize(tokens):
    if not tokens:
        return tokens
    if tokens[0] in ("how", "what"):
        if "?" not in tokens:
            tokens.append("?")
        return tokens
    while tokens and tokens[-1] in ("?", "what", "please"):
        tokens.pop()
    if tokens and tokens[0] == "please":
        tokens.pop(0)
    if len(tokens) == 1 and tokens[0] in SUBJECTS:
        tokens.append("?")
    return tokens


# Maps a misspelled word to its closest vocab word, if one is close enough.
def correct(word):
    if word == "?" or word in STOI:
        return word
    match = difflib.get_close_matches(word, KNOWN_WORDS, n=1, cutoff=0.75)
    return match[0] if match else word


# Returns (answer, notes). Spelling is corrected first, then the phrase is
# normalized. Refuses to guess when a word is truly unknown, because <unk>
# was never trained and any reply would be arbitrary.
def reply(params, text):
    notes = []
    words = []
    for w in text.lower().replace("?", " ? ").split():
        fixed = correct(w)
        if fixed != w:
            notes.append(f"'{w}' read as '{fixed}'")
        words.append(fixed)
    words = normalize(words)

    unknown = [w for w in words if w not in STOI]
    if unknown:
        return "", notes + [f"unknown word(s): {', '.join(unknown)}"]

    ids = [encode_word(w) for w in words]
    return " ".join(decode_ids(generate_int(params, ids))), notes


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
        answer, notes = reply(params, text)
        for note in notes:
            print(f"  ({note})")
        print("model>", answer if answer else "(no reply)")
