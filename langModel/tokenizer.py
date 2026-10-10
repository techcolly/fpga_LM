"""Word <-> id conversion and sliding-window example generation.

Context window is fixed at 4 tokens per the project spec. Each sentence is
turned into: [<pad> * 3, <bos>, w1, ..., wn, <eos>], then every
consecutive 4-token slice becomes one (context, target) training example.
The leading <pad>s let the model learn from a full-size context even for
the very first word of a sentence; learning to predict <eos> teaches it
when to stop during autoregressive generation.
"""

from langModel.vocab import STOI, ITOS, PAD_ID, BOS_ID, EOS_ID, UNK_ID

CONTEXT_SIZE = 4


# Looks up one word's token id, falling back to <unk> if it's not in the vocab.
def encode_word(word):
    return STOI.get(word, UNK_ID)


# Converts a list of words into a full token-id sequence, wrapped in <bos>/<eos>.
def encode_sentence(words):
    return [BOS_ID] + [encode_word(w) for w in words] + [EOS_ID]


# Converts a list of token ids back into their word strings.
def decode_ids(ids):
    return [ITOS[i] for i in ids]


# Slides a width-4 window over each encoded sentence to produce every
# (context, target) training pair -- see the module docstring for the scheme.
def build_training_examples(sentences, context_size=CONTEXT_SIZE):
    examples = []
    for words in sentences:
        seq = [PAD_ID] * (context_size - 1) + encode_sentence(words)
        for i in range(len(seq) - context_size):
            context = seq[i:i + context_size]
            target = seq[i + context_size]
            examples.append((context, target))
    return examples
