#!/bin/bash
set -e

echo "🧹 בונה את המנקה..."

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="המנקה"
EXECUTABLE="HaMenake"
DMG_NAME="המנקה-Installer"

# Use system swift
export PATH="/usr/bin:$PATH"

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build with Swift Package Manager
echo "⚙️  מקמפל עם Swift Package Manager..."
cd "$PROJECT_DIR"
/usr/bin/swift build -c release 2>&1

# Find the built executable
BUILT_EXEC="$PROJECT_DIR/.build/release/$EXECUTABLE"
if [ ! -f "$BUILT_EXEC" ]; then
    echo "❌ לא נמצא קובץ הפעלה ב: $BUILT_EXEC"
    exit 1
fi
echo "✅ נמצא קובץ הפעלה: $BUILT_EXEC"

# Create .app bundle structure
echo "📦 יוצר מבנה אפליקציה..."
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp "$BUILT_EXEC" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE"

# Copy Info.plist
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Create PkgInfo
echo -n "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Create app icon
echo "🎨 יוצר אייקון..."
python3 - <<'PYTHON_SCRIPT'
import struct
import zlib
import os
import math

def create_png(width, height, pixels):
    def chunk(chunk_type, data):
        c = chunk_type + data
        crc = struct.pack('>I', zlib.crc32(c) & 0xFFFFFFFF)
        return struct.pack('>I', len(data)) + c + crc
    header = b'\x89PNG\r\n\x1a\n'
    ihdr = chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
    raw_data = b''
    for y in range(height):
        raw_data += b'\x00'
        for x in range(width):
            idx = (y * width + x) * 4
            raw_data += bytes(pixels[idx:idx+4])
    idat = chunk(b'IDAT', zlib.compress(raw_data, 9))
    iend = chunk(b'IEND', b'')
    return header + ihdr + idat + iend

def create_icon(size):
    pixels = [0] * (size * size * 4)
    cx, cy = size / 2, size / 2
    r_outer = size * 0.46
    r_inner = size * 0.38
    corner_r = size * 0.18

    for y in range(size):
        for x in range(size):
            idx = (y * size + x) * 4
            # Rounded rectangle check
            nx = abs(x - cx)
            ny = abs(y - cy)
            in_rect = True
            edge_dist = 0
            if nx > r_outer - corner_r and ny > r_outer - corner_r:
                dx = nx - (r_outer - corner_r)
                dy = ny - (r_outer - corner_r)
                dist = math.sqrt(dx*dx + dy*dy)
                if dist > corner_r:
                    in_rect = False
                edge_dist = corner_r - dist
            elif nx > r_outer:
                in_rect = False
            elif ny > r_outer:
                in_rect = False
            else:
                edge_dist = min(r_outer - nx, r_outer - ny)

            if in_rect:
                # Gradient background - blue to teal
                t = y / size
                r = int(20 + t * 30)
                g = int(100 + t * 80)
                b = int(220 - t * 40)
                a = 255
                # Anti-alias edges
                if edge_dist < 1.5:
                    a = int(255 * max(0, min(1, edge_dist / 1.5)))

                # Sparkle/star pattern in center
                dx = x - cx
                dy = y - cy
                dist_center = math.sqrt(dx*dx + dy*dy)
                max_ray = size * 0.28

                if dist_center < max_ray and dist_center > 0:
                    angle = math.atan2(dy, dx)
                    # 4-point star
                    star_val = abs(math.cos(2 * angle))
                    star_r = max_ray * (0.15 + 0.85 * star_val)
                    if dist_center < star_r:
                        brightness = 1.0 - dist_center / star_r
                        brightness = brightness ** 0.6
                        r = min(255, int(r + (255 - r) * brightness * 0.9))
                        g = min(255, int(g + (255 - g) * brightness * 0.9))
                        b = min(255, int(b + (255 - b) * brightness * 0.7))

                    # Center glow
                    if dist_center < size * 0.08:
                        glow = 1.0 - dist_center / (size * 0.08)
                        r = min(255, int(r + (255 - r) * glow))
                        g = min(255, int(g + (255 - g) * glow))
                        b = min(255, int(b + (255 - b) * glow))

                    # Small sparkle dots
                    for spark_angle, spark_dist in [(0.8, 0.32), (2.3, 0.25), (4.1, 0.35), (5.5, 0.22)]:
                        sx = cx + math.cos(spark_angle) * size * spark_dist
                        sy = cy + math.sin(spark_angle) * size * spark_dist
                        sd = math.sqrt((x-sx)**2 + (y-sy)**2)
                        if sd < size * 0.025:
                            spark_b = 1.0 - sd / (size * 0.025)
                            r = min(255, int(r + (255 - r) * spark_b))
                            g = min(255, int(g + (255 - g) * spark_b))
                            b = min(255, int(b + (255 - b) * spark_b))

                pixels[idx] = r
                pixels[idx+1] = g
                pixels[idx+2] = b
                pixels[idx+3] = a
            else:
                pixels[idx:idx+4] = [0, 0, 0, 0]

    return create_png(size, size, pixels)

project_dir = os.environ.get('PROJECT_DIR', '.')
iconset_dir = os.path.join(project_dir, 'build', 'AppIcon.iconset')
os.makedirs(iconset_dir, exist_ok=True)

icon_sizes = [
    (16, 'icon_16x16.png'), (32, 'icon_16x16@2x.png'),
    (32, 'icon_32x32.png'), (64, 'icon_32x32@2x.png'),
    (128, 'icon_128x128.png'), (256, 'icon_128x128@2x.png'),
    (256, 'icon_256x256.png'), (512, 'icon_256x256@2x.png'),
    (512, 'icon_512x512.png'), (1024, 'icon_512x512@2x.png'),
]

for size, filename in icon_sizes:
    png_data = create_icon(size)
    with open(os.path.join(iconset_dir, filename), 'wb') as f:
        f.write(png_data)
    print(f"  Created {filename} ({size}x{size})")

print("Icon PNGs created")
PYTHON_SCRIPT

# Convert iconset to icns
if [ -d "$BUILD_DIR/AppIcon.iconset" ]; then
    iconutil -c icns "$BUILD_DIR/AppIcon.iconset" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null || echo "⚠️ Icon conversion failed, continuing without custom icon"
    rm -rf "$BUILD_DIR/AppIcon.iconset"
fi

echo "✅ אפליקציה נבנתה בהצלחה: $APP_BUNDLE"

# Create DMG
echo "💿 יוצר קובץ DMG..."
DMG_PATH="$BUILD_DIR/$DMG_NAME.dmg"
DMG_TEMP="$BUILD_DIR/dmg_temp"

mkdir -p "$DMG_TEMP"
cp -R "$APP_BUNDLE" "$DMG_TEMP/"

# Create a symbolic link to Applications folder
ln -s /Applications "$DMG_TEMP/Applications"

# Create DMG
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# Clean up temp
rm -rf "$DMG_TEMP"

echo ""
echo "========================================="
echo "🎉 הכל מוכן!"
echo "========================================="
echo "📍 אפליקציה: $APP_BUNDLE"
echo "💿 DMG: $DMG_PATH"
echo ""
echo "להתקנה: פתח את קובץ ה-DMG וגרור את המנקה לתיקיית Applications"
