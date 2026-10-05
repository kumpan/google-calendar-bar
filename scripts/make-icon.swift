// Renders the app icon in the Kumpan logo's geometry: square modules whose corners are either small
// (10/350 of a module) or swept into a full quarter circle.
//   swift scripts/make-icon.swift preview <out.png> [size]   one PNG of the chosen variant (512 px)
//   swift scripts/make-icon.swift sheet <out.png>            all variants side by side
//   swift scripts/make-icon.swift                            writes Resources/AppIcon.icns
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let purple: UInt32 = 0x451484, lavender: UInt32 = 0xD0CEFF // Kumpan brand colours

func color(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

/// macOS icon body: 824 pt squircle centered on a 1024 canvas (superellipse, n = 5).
func squircle() -> CGPath {
    let path = CGMutablePath(), n = 5.0, steps = 720
    for i in 0...steps {
        let t = Double(i) / Double(steps) * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = pow(abs(c), 2 / n) * (c < 0 ? -1 : 1), y = pow(abs(s), 2 / n) * (s < 0 ? -1 : 1)
        let p = CGPoint(x: 512 + x * 412, y: 512 + y * 412)
        i == 0 ? path.move(to: p) : path.addLine(to: p)
    }
    path.closeSubpath()
    return path
}

/// A rect in the 750-unit design space (y down, like the Kumpan SVG) with per-corner radii
/// [top-left, top-right, bottom-right, bottom-left].
func shape(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: [CGFloat]) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: x + r[0], y: y))
    p.addArc(tangent1End: CGPoint(x: x + w, y: y), tangent2End: CGPoint(x: x + w, y: y + h), radius: r[1])
    p.addArc(tangent1End: CGPoint(x: x + w, y: y + h), tangent2End: CGPoint(x: x, y: y + h), radius: r[2])
    p.addArc(tangent1End: CGPoint(x: x, y: y + h), tangent2End: CGPoint(x: x, y: y), radius: r[3])
    p.addArc(tangent1End: CGPoint(x: x, y: y), tangent2End: CGPoint(x: x + w, y: y), radius: r[0])
    p.closeSubpath()
    return p
}

let s: CGFloat = 10 // small corner

func circle(_ x: CGFloat, _ y: CGFloat, _ d: CGFloat) -> CGPath { shape(x, y, d, d, [d / 2, d / 2, d / 2, d / 2]) }

enum Variant: Int, CaseIterable {
    case dots = 1, header, kumpan

    /// Shapes in the 750 design space; holes are cut out with even-odd filling.
    var shapes: [CGPath] {
        switch self {
        case .dots: // header and a 3×2 month, today as the Kumpan quarter
            let d: CGFloat = (750 - 100) / 3
            var shapes = [shape(0, 0, 750, 175, [s, s, s, s])]
            for row in 0..<2 {
                for col in 0..<3 {
                    let x = CGFloat(col) * (d + 50), y = 225 + CGFloat(row) * (d + 50)
                    shapes.append(row == 0 && col == 2 ? shape(x, y, d, d, [s, s, d - s, s]) : circle(x, y, d))
                }
            }
            return shapes
        case .header: // calendar header over two days, the next meeting as the Kumpan quarter; centred vertically
            return [shape(0, 87.5, 750, 175, [s, s, s, s]), circle(0, 312.5, 350), shape(400, 312.5, 350, 350, [s, s, 340, s])]
        case .kumpan: // the Kumpan mark turned upside down: the leaf becomes the calendar's header
            return [shape(0, 0, 750, 350, [s, 340, s, 340]), circle(0, 400, 350), shape(400, 400, 350, 350, [s, s, 340, s])]
        }
    }
}

let chosen = Variant.dots

func render(_ variant: Variant, size: Int) -> CGImage {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(gray: 0, alpha: 0.3))
    ctx.addPath(squircle()); ctx.setFillColor(color(purple)); ctx.fillPath()
    ctx.restoreGState()

    // Same proportions as the Kumpan icon on its background: the mark is 750/1100 of the tile.
    let scale = 824 * 750 / 1100 / 750.0, origin = (1024 - 750 * scale) / 2
    var flip = CGAffineTransform(a: scale, b: 0, c: 0, d: -scale, tx: origin, ty: 1024 - origin)
    ctx.setFillColor(color(lavender))
    for path in variant.shapes {
        ctx.addPath(path.copy(using: &flip)!)
        ctx.fillPath(using: .evenOdd)
    }
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

let args = Array(CommandLine.arguments.dropFirst())
if args.first == "preview", args.count > 1 {
    writePNG(render(chosen, size: args.count > 2 ? Int(args[2]) ?? 512 : 512), to: URL(fileURLWithPath: args[1]))
    exit(0)
}
if args.first == "sheet", args.count > 1 {
    // Every variant at 400 px, with 32 px (Dock-small) versions underneath.
    let tile = 400, pad = 40, count = Variant.allCases.count
    let w = count * tile + (count + 1) * pad, h = tile + 3 * pad + 32
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(CGColor(gray: 0.93, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    for (i, v) in Variant.allCases.enumerated() {
        let x = pad + i * (tile + pad)
        ctx.draw(render(v, size: tile), in: CGRect(x: x, y: 2 * pad + 32, width: tile, height: tile))
        ctx.draw(render(v, size: 64), in: CGRect(x: x + tile / 2 - 16, y: pad, width: 32, height: 32))
    }
    writePNG(ctx.makeImage()!, to: URL(fileURLWithPath: args[1]))
    exit(0)
}

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        writePNG(render(chosen, size: base * scale), to: iconset.appendingPathComponent(name))
    }
}
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try proc.run()
proc.waitUntilExit()
print(proc.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns (\(chosen))" : "iconutil failed")
