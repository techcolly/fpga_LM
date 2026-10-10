"""Training corpus for the plant-monitoring tiny LM.

Every sentence is a plain list of words (no <bos>/<eos> -- the tokenizer
adds those). Kept to a handful of simple, repeated templates on purpose:
with only 3,680 parameters and a 4-token context, consistent structure is
what makes it realistic for the model to learn something recognizable.
"""

from langModel.vocab import STOI

SENTENCES = [
    # <part> <sensor> is <condition>
    "soil moisture is low".split(),
    "soil moisture is high".split(),
    "soil moisture is critical".split(),
    "soil temperature is cold".split(),
    "soil temperature is warm".split(),
    "leaf moisture is low".split(),
    "leaf temperature is hot".split(),
    "root moisture is critical".split(),
    "root moisture is normal".split(),
    "stem moisture is dry".split(),
    "flower humidity is low".split(),
    "plant humidity is normal".split(),
    "plant light is bright".split(),
    "plant light is dark".split(),
    "leaf light is low".split(),

    # <part> is <condition>
    "soil is dry".split(),
    "soil is wet".split(),
    "leaf is dry".split(),
    "leaf is healthy".split(),
    "stem is healthy".split(),
    "stem is stressed".split(),
    "root is healthy".split(),
    "root is stable".split(),
    "flower is stressed".split(),
    "flower is healthy".split(),
    "plant is healthy".split(),
    "plant is stressed".split(),
    "plant is stable".split(),

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

    # <action> the <part> now
    "water the soil now".split(),
    "water the plant now".split(),
    "check the leaf now".split(),
    "check the root now".split(),
    "monitor the stem now".split(),
    "adjust the light now".split(),
    "adjust the shade now".split(),

    # <sensor> <noun> is <condition> <state>
    "temperature is critical warning".split(),
    "moisture is critical danger".split(),
    "humidity is critical warning".split(),
    "light is critical alert".split(),
    "sensor is ok today".split(),
    "sensor error please check".split(),

    # misc short alerts
    "leaf is too dry".split(),
    "soil is too wet".split(),
    "light is too bright".split(),
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
]

_unknown = {w for s in SENTENCES for w in s if w not in STOI}
assert not _unknown, f"corpus uses words outside the 64-token vocab: {sorted(_unknown)}"
