"""Icons in EasyFind's style, for an EasyFind extension.

EasyFind's own icons are white outlines on a transparent 64x64 square:
lines about 5 px wide with rounded ends and corners, kept 5 to 10 px
from each edge. EasyFind paints every extension icon in the theme's icon
color, so an icon drawn this way matches its neighbors in every theme.

Needs Python 3 and Pillow (pip install pillow).

    python make_icon.py convert drawing.png icon.tga   a drawing from any editor
    python make_icon.py check icon.tga                 how close it is to the style
    python make_icon.py example bookmark.tga           the example extension's icon

To draw in code, copy draw_bookmark() below and change the shapes: the
Icon methods take 64 px units and draw at EasyFind's line width.

MIT licensed: copy freely.
"""

import sys
from PIL import Image, ImageDraw

SIZE = 64      # the icon, in pixels
SCALE = 8      # drawn larger, then scaled down for smooth edges
STROKE = 5     # EasyFind's line width at 64 px
WHITE = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)


class Icon:
    """A 64x64 canvas in EasyFind's style; coordinates in 64 px units."""

    def __init__(self):
        self.img = Image.new("RGBA", (SIZE * SCALE, SIZE * SCALE), CLEAR)
        self.draw = ImageDraw.Draw(self.img)

    def _px(self, v):
        return v * SCALE

    def _dot(self, x, y, r, fill=WHITE):
        x, y, r = self._px(x), self._px(y), self._px(r)
        self.draw.ellipse([x - r, y - r, x + r, y + r], fill=fill)

    def outline_rect(self, left, top, right, bottom, radius=8, width=STROKE):
        """A rounded rectangle, outline only."""
        self.draw.rounded_rectangle([self._px(left), self._px(top), self._px(right), self._px(bottom)],
                                    radius=self._px(radius), outline=WHITE, width=round(self._px(width)))

    def path(self, points, closed=False, width=STROKE):
        """Lines through the points, with rounded joins and ends."""
        pts = [(self._px(x), self._px(y)) for x, y in points]
        if closed:
            pts = pts + pts[:2]
        self.draw.line(pts, fill=WHITE, width=round(self._px(width)), joint="curve")
        for x, y in points:
            self._dot(x, y, width / 2)

    def circle(self, cx, cy, r, width=STROKE):
        """A ring."""
        x, y, rr = self._px(cx), self._px(cy), self._px(r)
        self.draw.ellipse([x - rr, y - rr, x + rr, y + rr], outline=WHITE, width=round(self._px(width)))

    def dot(self, cx, cy, r=3):
        """A filled dot, for small details."""
        self._dot(cx, cy, r)

    def bar(self, x1, x2, y, width=STROKE):
        """A short horizontal line with rounded ends, like a text line."""
        self.draw.rounded_rectangle([self._px(x1), self._px(y - width / 2), self._px(x2), self._px(y + width / 2)],
                                    radius=self._px(width / 2), fill=WHITE)

    def clear(self, left, top, right, bottom):
        """Erases a rectangle: room around a shape laid over another."""
        self.draw.rectangle([self._px(left), self._px(top), self._px(right), self._px(bottom)], fill=CLEAR)

    def save(self, path):
        self.img.resize((SIZE, SIZE), Image.LANCZOS).save(path)
        print(f"{path} written")


def draw_bookmark(path):
    """The example extension's icon: a ribbon bookmark."""
    icon = Icon()
    icon.path([(17, 9), (47, 9), (47, 56), (32, 44), (17, 56)], closed=True)
    icon.save(path)


def coverage(img):
    """How much ink each pixel holds, 0 to 255, from any kind of drawing."""
    rgba = img.convert("RGBA")
    alpha = rgba.getchannel("A")
    lo, hi = alpha.getextrema()
    if lo < 250:
        return alpha
    # No transparency: the ink is whatever differs from the corner color.
    gray = rgba.convert("L")
    if gray.getpixel((0, 0)) > 127:
        return gray.point(lambda v: 255 - v)
    return gray


def convert(src, dst):
    img = Image.open(src)
    w, h = img.size
    if w != h:
        print(f"{src} is {w}x{h}: draw on a square canvas (the template is one).")
        return 1
    ink = coverage(img).resize((SIZE, SIZE), Image.LANCZOS)
    out = Image.new("RGBA", (SIZE, SIZE), WHITE)
    out.putalpha(ink)
    out.save(dst)
    print(f"{dst} written")
    return check(dst)


def check(path):
    img = Image.open(path).convert("RGBA")
    notes = []
    if img.size != (SIZE, SIZE):
        notes.append(f"It is {img.size[0]}x{img.size[1]}; EasyFind's icons are 64x64 (the game needs a power of two).")
    px = img.load()
    colored = 0
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = px[x, y]
            if a > 200 and (max(r, g, b) - min(r, g, b) > 30 or min(r, g, b) < 180):
                colored += 1
    if colored:
        notes.append("Some of it is colored or gray. EasyFind paints the whole icon in one color, so draw in white.")
    box = img.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
    if not box:
        print("The icon is empty.")
        return 1
    left, top, right, bottom = box[0], box[1], img.size[0] - box[2], img.size[1] - box[3]
    if min(left, top, right, bottom) < 2:
        notes.append(f"It touches the edge (margins {left}, {top}, {right}, {bottom} px). Keep 5 to 10 px clear on each side.")
    span = max(box[2] - box[0], box[3] - box[1])
    if span < 42:
        notes.append(f"It spans {span} px; EasyFind's span 44 to 56, so it would look small beside them.")
    runs = []
    for y in range(img.size[1]):
        run = 0
        for x in range(img.size[0]):
            if px[x, y][3] > 128:
                run += 1
            elif run:
                runs.append(run)
                run = 0
        if run:
            runs.append(run)
    runs.sort()
    stroke = runs[len(runs) // 2] if runs else 0
    if stroke and stroke < 3:
        notes.append(f"Lines look about {stroke} px wide. Thin lines break apart at menu size; aim for about 5.")
    if notes:
        print(f"{path}: close. A few things would make it match EasyFind's icons:")
        for n in notes:
            print("  - " + n)
    else:
        print(f"{path}: matches the style: 64x64, white, margins {left}, {top}, {right}, {bottom} px, lines about {stroke} px.")
    return 0


def main(argv):
    if len(argv) == 3 and argv[0] == "convert":
        return convert(argv[1], argv[2])
    if len(argv) == 2 and argv[0] == "check":
        return check(argv[1])
    if len(argv) == 2 and argv[0] == "example":
        draw_bookmark(argv[1])
        return check(argv[1])
    print(__doc__)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
