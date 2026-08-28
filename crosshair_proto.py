"""
Renders ONE grappler crosshair corner piece as a transparent PNG
(materials/beatrun/gears/grappler/crosshair_corner.png). Lua draws 4 rotated copies of this one
texture, each independently positioned, to allow a real positional "open" effect (pieces nudge
outward from center) -- keep the nudge distance small relative to the drawn size in crosshair.lua
or the 4 pieces visually disconnect into a scatter instead of reading as one circle.

The circle's center is placed at the exact center of the square canvas, so rotating this texture
in Lua rotates the arc around that same shared point.

Run: /tmp/crosshair_venv/bin/python3 crosshair_proto.py
"""
import math
from PIL import Image, ImageDraw

# --- tweak these and re-run ---
CANVAS_SIZE = 256          # final PNG is CANVAS_SIZE x CANVAS_SIZE
SUPERSAMPLE = 4            # render bigger then downscale, for smooth anti-aliased edges
START_ANGLE_DEG = 0        # 0 = straight up, clockwise
SPAN_DEG = 60              # how much of the circle this one corner covers
SEGMENTS = 48              # smoothness of the curve
RADIUS_FRACTION = 0.5      # arc radius as a fraction of the canvas half-size
LINE_WIDTH = 10            # white line thickness (px, at final resolution)
OUTLINE_WIDTH = 4          # extra black outline thickness on each side (px, at final resolution)
# -------------------------------

size = CANVAS_SIZE * SUPERSAMPLE
center = size / 2
radius = center * RADIUS_FRACTION
line_width = LINE_WIDTH * SUPERSAMPLE
outline_width = OUTLINE_WIDTH * SUPERSAMPLE

def circle_point(angle_deg):
    a = math.radians(angle_deg)
    return (center + radius * math.sin(a), center - radius * math.cos(a))

points = [circle_point(START_ANGLE_DEG + t / SEGMENTS * SPAN_DEG) for t in range(SEGMENTS + 1)]

img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# black outline first (wider line), then white on top (narrower line) -- classic outline trick
draw.line(points, fill=(0, 0, 0, 255), width=line_width + outline_width * 2, joint="curve")
for p in points:
    r = (line_width + outline_width * 2) / 2
    draw.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=(0, 0, 0, 255))

draw.line(points, fill=(255, 255, 255, 255), width=line_width, joint="curve")
for p in points:
    r = line_width / 2
    draw.ellipse([p[0] - r, p[1] - r, p[0] + r, p[1] + r], fill=(255, 255, 255, 255))

img = img.resize((CANVAS_SIZE, CANVAS_SIZE), Image.LANCZOS)

out_path = "materials/beatrun/gears/grappler/crosshair_corner.png"
img.save(out_path)
print("saved", out_path)
