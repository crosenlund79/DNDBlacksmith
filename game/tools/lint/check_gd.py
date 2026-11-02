"""Static checks for GDScript without the engine: syntax (gdtoolkit's gdparse) plus heuristics for
Godot 4 type-inference errors (':=' with a Variant right-hand side)."""
import re, subprocess, sys, pathlib
root = pathlib.Path(__file__).resolve().parents[2]
files = sorted(root.glob("scripts/**/*.gd")) + sorted(root.glob("tests/*.gd"))
bad = 0
for f in files:
    r = subprocess.run(["gdparse", str(f)], capture_output=True, text=True)
    if r.returncode != 0:
        bad += 1
        print(f"SYNTAX {f.relative_to(root)}:\n{(r.stderr or r.stdout)[:800]}")
risky = re.compile(r"\b(var|const)\s+\w+\s*:=\s*(.*)$")
variant_rhs = re.compile(r"(^|[^\w.])(max|min|clamp|abs|round|floor|ceil|sign|lerp)\(|\.get\(|pick_random\(|\.pop_front\(|\.pop_back\(|\.front\(|\.back\(|JSON\.parse_string|\]\s*$|\]\s*[-+*/%]|^[\w.]+\[[^\]]+\]$")
for f in files:
    for i, line in enumerate(f.read_text().splitlines(), 1):
        m = risky.search(line)
        if not m:
            continue
        rhs = m.group(2).strip()
        if re.match(r"^[\[{\"]", rhs) and ".get(" not in rhs.split("]")[-1].split("}")[-1]:
            continue
        if variant_rhs.search(rhs) and not re.match(r"^(int|float|str|bool|String|Vector2|Color|Array|Dictionary)\(", rhs) and " as " not in rhs:
            print(f"INFER {f.relative_to(root)}:{i}: {line.strip()}")
            bad += 1
print("files:", len(files), "issues:", bad)
sys.exit(1 if bad else 0)
