# Extra content modules

`make_data.py` imports every `extra_*.py` in this folder (sorted by name). A module may define:

- `ITEMS` — a list of item dicts, built with `from make_data_helpers import it, ch, L, P` (id, name, type, slot, value, stats, icon, stack, desc, tags).
- `CHARACTERS` — a list of character dicts (same shape as `ch(...)` in make_data.py).
- `PROPS` — a dict of prop id → {size: [w, h], solid: bool, desc}.

One module per system keeps parallel work from colliding in make_data.py.
