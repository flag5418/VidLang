#!/usr/bin/env python3
"""Generate a high-quality launcher icon using Material Icons font + Pillow."""

from PIL import Image, ImageDraw, ImageFont
import os

FONT_PATH = "/Volumes/Expand/wangqingquan/Documents/developer/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf"
OUTPUT_PATH = "assets/Logo/launcher_icon.png"

SIZE = 1024
BG_COLOR = (30, 136, 229)      # #1E88E5 (Material Blue 600)
ICON_COLOR = (255, 255, 255)    # White
PADDING_RATIO = 0.22            # 22% padding on each side

SCHOOL_CODEPOINT = 0xE559       # Icons.school

def main():
    # Create image with blue background
    img = Image.new("RGBA", (SIZE, SIZE), BG_COLOR + (255,))
    draw = ImageDraw.Draw(img)

    # Load Material Icons font at large size
    icon_size = int(SIZE * (1 - PADDING_RATIO * 2))
    font = ImageFont.truetype(FONT_PATH, icon_size)

    # Get the school icon character
    icon_char = chr(SCHOOL_CODEPOINT)

    # Measure text bbox for centering
    bbox = draw.textbbox((0, 0), icon_char, font=font)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]

    # Center the icon
    x = (SIZE - text_w) // 2 - bbox[0]
    y = (SIZE - text_h) // 2 - bbox[1]

    # Draw the icon
    draw.text((x, y), icon_char, fill=ICON_COLOR + (255,), font=font)

    # Save
    img.save(OUTPUT_PATH, "PNG")
    print(f"✅ Generated {OUTPUT_PATH} ({os.path.getsize(OUTPUT_PATH)} bytes, {SIZE}x{SIZE})")

if __name__ == "__main__":
    main()
