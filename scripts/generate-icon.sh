#!/bin/bash
set -euo pipefail

# Generate AppIcon.icns from a programmatically created PNG using macOS native tools
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OUTPUT="${PROJECT_DIR}/Sources/LSLS/Resources/AppIcon.icns"
ICONSET_DIR="$(mktemp -d)/AppIcon.iconset"
SWIFT_FILE="$(mktemp).swift"
mkdir -p "$ICONSET_DIR"

# Write the icon generator Swift program
cat > "$SWIFT_FILE" << 'SWIFT'
import AppKit

let outputPath = CommandLine.arguments[1]
let size = 1024

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx

// Dark background with rounded corners
let bgColor = NSColor(red: 0.10, green: 0.10, blue: 0.18, alpha: 1.0)
bgColor.setFill()
NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size), xRadius: 180, yRadius: 180).fill()

// "LS" text in accent color
let accentColor = NSColor(red: 0.91, green: 0.27, blue: 0.37, alpha: 1.0)
let text = "LS" as NSString
let fontSize: CGFloat = 420
let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: accentColor,
]
let textSize = text.size(withAttributes: attrs)
let x = (CGFloat(size) - textSize.width) / 2
let y = (CGFloat(size) - textSize.height) / 2
text.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)

NSGraphicsContext.restoreGraphicsState()

let data = rep.representation(using: .png, properties: [:])!
let url = URL(fileURLWithPath: outputPath)
try! data.write(to: url)
SWIFT

# Compile and run the icon generator
BASE_PNG="$(mktemp).png"
swiftc -framework AppKit "$SWIFT_FILE" -o "${SWIFT_FILE}.bin"
"${SWIFT_FILE}.bin" "$BASE_PNG"

# Create all required icon sizes
declare -a SIZES=(16 32 64 128 256 512)
for s in "${SIZES[@]}"; do
    sips -z $s $s "$BASE_PNG" --out "${ICONSET_DIR}/icon_${s}x${s}.png" > /dev/null 2>&1
    s2=$((s * 2))
    sips -z $s2 $s2 "$BASE_PNG" --out "${ICONSET_DIR}/icon_${s}x${s}@2x.png" > /dev/null 2>&1
done

# Also add the 512@2x (1024)
cp "$BASE_PNG" "${ICONSET_DIR}/icon_512x512@2x.png"

# Convert iconset to icns
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT"

# Clean up
rm -f "$BASE_PNG" "$SWIFT_FILE" "${SWIFT_FILE}.bin"
rm -rf "$(dirname "$ICONSET_DIR")"

echo "Generated: ${OUTPUT}"
