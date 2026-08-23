# Markdown Diagram Editing — Pitfalls & Verification

Session-proven quirks from converting ASCII diagrams to mermaid inside normative .md docs.

## Pitfall 1: stray fences when replacing an ASCII diagram

When an ASCII diagram sits inside a ` ``` ` fenced block, the fences are NOT
part of the diagram text. If your `old_text`/`old_string` covers only the
diagram interior, the replacement lands BETWEEN the old fences, producing:

    ```
    ```mermaid
    ...
    ```

…which renders as literal text and unbalances the document. **Always include
the opening AND closing fence lines in old_text** so the replacement is one
atomic block. If you forget, the diff evidence shows the doubled fence
immediately — fix with two small edits (remove stray fence before `mermaid`
line, remove stray fence after closing fence) rather than re-replacing the
whole diagram.

## Pitfall 2: ASCII-art whitespace defeats exact-match editing

Hand-drawn box diagrams contain long runs of spaces and box-drawing chars
whose exact counts are invisible in rendered reads. Exact-match replace fails
with "old_string not found" even when the text looks identical. After TWO
exact-match failures on the same region, switch to the fuzzy-matching patcher
(hermes_tools.patch via execute_code) — it tolerates whitespace drift and
returns a unified diff to confirm the right lines changed. Do not keep
guessing invisible space counts.

## Pitfall 3: lean-ctx ctx_patch batched ops

`ctx_patch` with `ops=[...]` requires each op to carry an explicit `op` field
(e.g. `"op": "replace_unique"`); bare `{old_text, new_text}` items are
rejected with `missing 'op'`. The top-level single-op shape infers the op
from its own parameters, but batched ops do not.

## Mermaid style conventions (conservative, renders everywhere)

- `flowchart LR` for layer/boundary maps: one `subgraph` per layer, `direction TB` inside, dotted edges (`-.->`) for "depends on Ports" (dependency inversion), thick edges (`==>`) for composition-root wiring.
- `sequenceDiagram` + `autonumber` for request/wiring traces (config load → selection → injection → call).
- Quote all node labels; use `<br>` for line breaks inside labels; HTML-escape angle brackets in generic path placeholders (`contexts.&lt;bc&gt;.application/`).

## Post-edit verification recipe (run after any diagram conversion)

```python
import re
text = open(path).read()
fences = re.findall(r"^```(\w*).*$", text, flags=re.M)
assert text.count("```") % 2 == 0, "unbalanced fences"
for m in re.finditer(r"```mermaid\n(.*?)```", text, flags=re.S):
    print(m.group(1).strip().splitlines()[0])  # flowchart LR / sequenceDiagram
```

For distilled/generic docs, also grep for the origin project's vocabulary
(product names, domain terms, internal paths) and require zero matches —
one leaked term breaks the "portable to other projects" guarantee.
