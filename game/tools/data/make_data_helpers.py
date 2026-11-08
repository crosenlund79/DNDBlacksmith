"""Helpers shared by make_data.py and the extra_*.py content modules (same shapes as in make_data.py)."""


def it(id, name, type, slot=None, value=10, stats=None, icon=None, stack=False, desc="", tags=None):
    return dict(id=id, name=name, type=type, slot=slot, value=value, stats=stats or {}, icon=icon or id,
                stack=stack, desc=desc, tags=tags or [])


def ch(id, name, kind, look, **kw):
    d = dict(id=id, name=name, kind=kind, look=look, sprite=f"chars/{id}", portrait=f"portraits/{id}")
    d.update(kw)
    return d


L = lambda **k: k
P = lambda w, h, solid=True, desc="": dict(size=[w, h], solid=solid, desc=desc)
