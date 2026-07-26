from pathlib import Path
import os
import sys

i8dot = os.environ.get("I8DOT")
if not i8dot:
    roots = [Path.cwd(), Path(os.environ.get("NIX_BUILD_TOP", "/build"))]
    for root in roots:
        matches = list(root.glob("**/rten-gemm-0.24.0/src/i8dot.rs"))
        if matches:
            i8dot = str(matches[0])
            break

if not i8dot or not Path(i8dot).is_file():
    print("rten-gemm i8dot.rs not found", file=sys.stderr)
    sys.exit(1)

p = Path(i8dot)
text = p.read_text()

marker_a = (
    "            // Base ISA features\n"
    '            #[target_feature(enable = "avx512f")]'
)
start = text.index(marker_a)
end = text.index("            // Base ISA features (no extensions required)")
text = text[:start] + text[end:]

start = text.index("    pub struct Avx512VnniIsa {")
end = text.index("    pub struct Avx2Int8DotIsa {")
text = text[:start] + text[end:]

text = text.replace(
    "use rten_simd::isa::{Avx2Isa, Avx512Isa};",
    "use rten_simd::isa::Avx2Isa;",
)

p.write_text(text)
