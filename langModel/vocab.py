"""Fixed 64-token word-level vocabulary for the plant-monitoring tiny LM."""

# <pad>: left-pads the context before a sentence has 4 real tokens yet,
#        so even the first word of a sentence is predicted from a full-size window.
# <bos>: this marks the start of a sentence right after any padding
# <eos>: marks the end of a sentence -- the model learns to predict this so
#        autoregressive generation knows when to stop instead of running forever.
# <unk>: fallback id for any word typed at inference time that isn't one of
#        the 64 known tokens (e.g. a live demo typo), so lookup degrades
#        gracefully instead of crashing.
SPECIAL_TOKENS = ["<pad>", "<bos>", "<eos>", "<unk>"]

PLANT_PARTS = ["soil", "leaf", "stem", "root", "flower", "plant"]

SENSOR_NOUNS = ["moisture", "temperature", "light", "humidity", "sensor"]

CONDITIONS = [
    "dry", "wet", "hot", "cold", "bright", "dark",
    "warm", "low", "high", "normal", "critical", "stable",
]

# Question markers so prompts like "soil dry what ?" can be answered.
QUESTION = ["?", "what", "how"]

ACTIONS = [
    "water", "check", "needs", "alert", "warn", "grow", "wilt", "droop",
    "recover", "monitor", "adjust", "rising", "falling", "increase",
]

STATES = ["healthy", "stressed", "danger", "warning", "ok", "good", "error", "done"]

CONNECTORS = ["is", "the", "and", "too", "very", "now", "please", "today"]

EXTRA = ["decrease", "sun", "shade", "night"]

VOCAB = (
    SPECIAL_TOKENS
    + PLANT_PARTS
    + SENSOR_NOUNS
    + CONDITIONS
    + ACTIONS
    + STATES
    + CONNECTORS
    + QUESTION
    + EXTRA
)

assert len(VOCAB) == 64, f"expected 64 tokens, got {len(VOCAB)}"
assert len(set(VOCAB)) == 64, "duplicate token in vocab"

STOI = {tok: i for i, tok in enumerate(VOCAB)}
ITOS = {i: tok for i, tok in enumerate(VOCAB)}

PAD_ID = STOI["<pad>"]
BOS_ID = STOI["<bos>"]
EOS_ID = STOI["<eos>"]
UNK_ID = STOI["<unk>"]
