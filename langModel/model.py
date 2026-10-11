"""The tiny feedforward LM: embed 4 context tokens, 32->32 ReLU, 32->64 logits.

Mirrors the shared spec exactly:
    x = concat(E[t0], E[t1], E[t2], E[t3])
    h = clamp(ReLU(W1 x + b1), 0, 127/16)   # ReLU, capped like the INT8 hardware
    z = W2 h + b2
    t_next = argmax(z)
"""

import torch.nn as nn

VOCAB_SIZE = 64
EMBED_DIM = 8
CONTEXT_SIZE = 4
HIDDEN_DIM = 32  # == CONTEXT_SIZE * EMBED_DIM, i.e. the concatenated embeddings

# The hardware clamps hidden activations to [0, 127] at scale 16, i.e. a real
# value of 127/16. Training with the same cap keeps the float model from using
# values the INT8 pipeline cannot represent.
HIDDEN_MAX = 127 / 16


class TinyLM(nn.Module):
    def __init__(self):
        super().__init__()
        self.embedding = nn.Embedding(VOCAB_SIZE, EMBED_DIM)
        self.fc1 = nn.Linear(CONTEXT_SIZE * EMBED_DIM, HIDDEN_DIM)
        self.fc2 = nn.Linear(HIDDEN_DIM, VOCAB_SIZE)

    # context_ids: LongTensor of shape (batch, 4) -> logits of shape (batch, 64)
    def forward(self, context_ids):
        embedded = self.embedding(context_ids)          # (batch, 4, 8)
        x = embedded.flatten(start_dim=1)                # (batch, 32) -- the concat
        h = self.fc1(x).clamp(min=0.0, max=HIDDEN_MAX)   # ReLU + hardware cap, (batch, 32)
        z = self.fc2(h)                                  # (batch, 64)
        return z
