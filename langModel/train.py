"""Trains TinyLM on the plant-monitoring corpus and samples some generations.

Full-batch gradient descent (no mini-batching): the training windows and the
3,680 parameters both fit trivially in memory, so there's no reason to add
batching complexity here.
"""

from pathlib import Path

import torch
import torch.nn.functional as F

from langModel.corpus import SENTENCES
from langModel.model import TinyLM
from langModel.tokenizer import CONTEXT_SIZE, build_training_examples, decode_ids, encode_word
from langModel.vocab import BOS_ID, EOS_ID, PAD_ID


def build_dataset():
    examples = build_training_examples(SENTENCES)
    contexts = torch.tensor([ctx for ctx, _ in examples], dtype=torch.long)
    targets = torch.tensor([tgt for _, tgt in examples], dtype=torch.long)
    return contexts, targets


def train(epochs=1500, lr=0.05):
    contexts, targets = build_dataset()
    model = TinyLM()
    optimizer = torch.optim.Adam(model.parameters(), lr=lr)

    for epoch in range(epochs):
        optimizer.zero_grad()
        logits = model(contexts)
        loss = F.cross_entropy(logits, targets)
        loss.backward()
        optimizer.step()

        if epoch % 250 == 0 or epoch == epochs - 1:
            acc = (logits.argmax(dim=-1) == targets).float().mean().item()
            print(f"epoch {epoch:4d}  loss={loss.item():.4f}  train_acc={acc:.3f}")

    return model


# Feeds a seed prompt in, then repeatedly predicts the next word and feeds it
# back as context (autoregressive generation), stopping at <eos> or max_len.
def generate(model, prompt_words=(), max_len=12):
    model.eval()
    ids = [PAD_ID] * (CONTEXT_SIZE - 1) + [BOS_ID] + [encode_word(w) for w in prompt_words]
    generated_ids = []
    with torch.no_grad():
        for _ in range(max_len):
            context = ids[-CONTEXT_SIZE:]
            logits = model(torch.tensor([context], dtype=torch.long))
            next_id = int(logits.argmax(dim=-1).item())
            if next_id == EOS_ID:
                break
            ids.append(next_id)
            generated_ids.append(next_id)
    return decode_ids(generated_ids)


if __name__ == "__main__":
    model = train()
    torch.save(model.state_dict(), Path(__file__).resolve().parent / "checkpoint.pt")

    print("\nsample generations:")
    for seed in [(), ("soil",), ("plant", "needs"), ("temperature", "is"), ("leaf",)]:
        words = generate(model, seed)
        print(f"  seed={seed!r:30} -> {' '.join(words)}")
