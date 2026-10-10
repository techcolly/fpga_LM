"""The tiny feedforward LM: embed 4 context tokens, 32->32 ReLU, 32->64 logits.

Mirrors the shared spec exactly:
    x = concat(E[t0], E[t1], E[t2], E[t3])
    h = ReLU(W1 x + b1)
    z = W2 h + b2
    t_next = argmax(z)
"""

import torch.nn as nn

VOCAB_SIZE = 64
EMBED_DIM = 8
CONTEXT_SIZE = 4
HIDDEN_DIM = 32  # == CONTEXT_SIZE * EMBED_DIM, i.e. the concatenated embeddings


class TinyLM(nn.Module):
    def __init__(self):
        super().__init__()
        self.embedding = nn.Embedding(VOCAB_SIZE, EMBED_DIM)
        self.fc1 = nn.Linear(CONTEXT_SIZE * EMBED_DIM, HIDDEN_DIM)
        self.fc2 = nn.Linear(HIDDEN_DIM, VOCAB_SIZE)
        self.relu = nn.ReLU()

    # context_ids: LongTensor of shape (batch, 4) -> logits of shape (batch, 64)
    def forward(self, context_ids):
        embedded = self.embedding(context_ids)          # (batch, 4, 8)
        x = embedded.flatten(start_dim=1)                # (batch, 32) -- the concat
        h = self.relu(self.fc1(x))                       # (batch, 32)
        z = self.fc2(h)                                  # (batch, 64)
        return z
