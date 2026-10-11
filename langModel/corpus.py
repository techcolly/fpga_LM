"""Training corpus for the plant-monitoring tiny LM.

Every sentence is a plain list of words (no <bos>/<eos> -- the tokenizer
adds those). Kept to a handful of simple, repeated templates on purpose:
with only 3,680 parameters and a 4-token context, consistent structure is
what makes it realistic for the model to learn something recognizable.
"""

from langModel.vocab import STOI

SENTENCES = [
    # <part> needs <action>
    "soil needs water".split(),
    "leaf needs water".split(),
    "root needs water".split(),
    "flower needs water".split(),
    "plant needs water".split(),
    "plant needs sun".split(),
    "plant needs shade".split(),

    # <sensor> is <rising/falling> please <action>
    "temperature is rising please check".split(),
    "temperature is falling please monitor".split(),
    "moisture is falling please water".split(),
    "moisture is rising please check".split(),
    "humidity is rising please adjust".split(),
    "humidity is falling please check".split(),
    "light is rising please adjust".split(),
    "light is falling please check".split(),

    # <sensor> <noun> is <condition> <state>
    "temperature is critical warning".split(),
    "moisture is critical danger".split(),
    "humidity is critical warning".split(),
    "light is critical alert".split(),
    "sensor is ok today".split(),
    "sensor error please check".split(),

    # misc short alerts
    "sun is too bright today".split(),
    "night light is too dark".split(),
    "plant recover today".split(),
    "plant danger please check".split(),
    "stem wilt danger".split(),
    "leaf wilt warning".split(),
    "root droop warning".split(),
    "plant grow today".split(),
    "soil moisture increase now".split(),
    "soil moisture decrease now".split(),
    "temperature increase today".split(),
    "temperature decrease today".split(),
    "plant is good today".split(),
    "plant is done today".split(),

    # status question: "how is <part> ?"
    "how is soil ? soil is wet".split(),
    "how is leaf ? leaf is healthy".split(),
    "how is stem ? stem is healthy".split(),
    "how is root ? root is stable".split(),
    "how is flower ? flower is healthy".split(),
    "how is plant ? plant is healthy".split(),

    # sensor question: "<sensor> ?"
    "temperature ? temperature is normal".split(),
    "moisture ? moisture is low".split(),
    "humidity ? humidity is normal".split(),
    "light ? light is bright".split(),
    "sensor ? sensor is ok today".split(),

]

# Condition -> advice. The user states a condition ("soil is dry") and the
# model continues with what to do. This is a tiny learned lookup table; there
# is no sensor, the condition comes from whatever the user types.
OK = "the plant is ok today"
WATER = "the soil needs water"
SHADE = "adjust the shade now"
SUN = "the plant needs sun"
ROOT = "please check the root now"
LEAF = "please check the leaf now"
LIGHT = "adjust the light now"

PART_ADVICE = {  # "<part> is <condition> <advice>"
    ("soil", "dry"): WATER, ("soil", "wet"): ROOT, ("soil", "hot"): SHADE, ("soil", "cold"): SUN,
    ("root", "dry"): WATER, ("root", "wet"): ROOT, ("root", "healthy"): OK, ("root", "stable"): OK,
    ("leaf", "dry"): WATER, ("leaf", "wet"): ROOT, ("leaf", "hot"): SHADE, ("leaf", "healthy"): OK,
    ("stem", "dry"): WATER, ("stem", "healthy"): OK, ("stem", "stressed"): LEAF,
    ("flower", "dry"): WATER, ("flower", "healthy"): OK, ("flower", "stressed"): LEAF,
    ("plant", "dry"): WATER, ("plant", "wet"): ROOT, ("plant", "hot"): SHADE, ("plant", "cold"): SUN,
    ("plant", "bright"): SHADE, ("plant", "dark"): SUN, ("plant", "healthy"): OK,
    ("plant", "stable"): OK, ("plant", "stressed"): LEAF,
}

SENSOR_ADVICE = {  # "<sensor> is <condition> <advice>"
    ("moisture", "low"): WATER, ("moisture", "high"): ROOT, ("moisture", "normal"): OK,
    ("temperature", "high"): SHADE, ("temperature", "hot"): SHADE,
    ("temperature", "low"): SUN, ("temperature", "cold"): SUN, ("temperature", "normal"): OK,
    ("light", "low"): LIGHT, ("light", "dark"): LIGHT, ("light", "high"): SHADE,
    ("light", "bright"): SHADE, ("light", "normal"): OK,
    ("humidity", "low"): WATER, ("humidity", "high"): SHADE, ("humidity", "normal"): OK,
}

COMBO_ADVICE = {  # "<part> <sensor> is <condition> <advice>"
    ("soil", "moisture", "low"): WATER, ("soil", "moisture", "high"): ROOT,
    ("soil", "moisture", "normal"): OK,
    ("leaf", "temperature", "hot"): SHADE, ("leaf", "temperature", "cold"): SUN,
    ("leaf", "temperature", "normal"): OK,
    ("plant", "light", "bright"): SHADE, ("plant", "light", "dark"): LIGHT,
    ("plant", "light", "low"): LIGHT,
    ("plant", "humidity", "low"): WATER, ("plant", "humidity", "high"): SHADE,
    ("plant", "humidity", "normal"): OK,
}

TOO_ADVICE = {  # "<subject> is too <condition> <advice>"
    ("leaf", "dry"): WATER, ("soil", "dry"): WATER, ("soil", "wet"): ROOT,
    ("plant", "hot"): SHADE, ("plant", "cold"): SUN, ("light", "bright"): SHADE,
}

for (a, cond), advice in PART_ADVICE.items():
    SENTENCES.append(f"{a} is {cond} {advice}".split())
    SENTENCES.append(f"the {a} is {cond} {advice}".split())
for (a, cond), advice in SENSOR_ADVICE.items():
    SENTENCES.append(f"{a} is {cond} {advice}".split())
    SENTENCES.append(f"the {a} is {cond} {advice}".split())
for (a, b, cond), advice in COMBO_ADVICE.items():
    SENTENCES.append(f"{a} {b} is {cond} {advice}".split())
for (a, cond), advice in TOO_ADVICE.items():
    SENTENCES.append(f"{a} is too {cond} {advice}".split())


# Shorter phrasings without "is" ("plant dry"), and commands that get "done".
# "please" is stripped by the chat layer, so it is not trained here.
for (a, cond), advice in PART_ADVICE.items():
    SENTENCES.append(f"{a} {cond} {advice}".split())
for (a, cond), advice in SENSOR_ADVICE.items():
    SENTENCES.append(f"{a} {cond} {advice}".split())
for (a, b, cond), advice in COMBO_ADVICE.items():
    SENTENCES.append(f"{a} {b} {cond} {advice}".split())

COMMANDS = [
    ("water", "soil"), ("water", "plant"), ("check", "leaf"), ("check", "root"),
    ("monitor", "stem"), ("adjust", "light"), ("adjust", "shade"),
]
for verb, thing in COMMANDS:
    SENTENCES.append(f"{verb} the {thing} done".split())

# Natural phrasings of the status questions ("how is the plant ?").
STATUS_ANSWER = {
    "soil": "soil is wet", "leaf": "leaf is healthy", "stem": "stem is healthy",
    "root": "root is stable", "flower": "flower is healthy", "plant": "plant is healthy",
}
SENSOR_ANSWER = {
    "temperature": "temperature is normal", "moisture": "moisture is low",
    "humidity": "humidity is normal", "light": "light is bright", "sensor": "sensor is ok today",
}
for part, answer in STATUS_ANSWER.items():
    SENTENCES.append(f"how is the {part} ? {answer}".split())
    SENTENCES.append(f"{part} ? {answer}".split())
for sensor, answer in SENSOR_ANSWER.items():
    SENTENCES.append(f"what is {sensor} ? {answer}".split())
    SENTENCES.append(f"what is the {sensor} ? {answer}".split())
    SENTENCES.append(f"how is the {sensor} ? {answer}".split())

_unknown = {w for s in SENTENCES for w in s if w not in STOI}
assert not _unknown, f"corpus uses words outside the 64-token vocab: {sorted(_unknown)}"
