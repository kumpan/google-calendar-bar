// Renders the app icon.
//   swift scripts/make-icon.swift preview <out.png> [size]   PNG, 512 px unless given
//   swift scripts/make-icon.swift                     writes Resources/AppIcon.icns
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func gradient(_ hexes: [UInt32], _ alpha: [CGFloat]? = nil) -> CGGradient {
    let colors = hexes.enumerated().map { color($1, alpha?[$0] ?? 1) }
    let locs = (0..<hexes.count).map { CGFloat($0) / CGFloat(max(hexes.count - 1, 1)) }
    return CGGradient(colorsSpace: nil, colors: colors as CFArray, locations: locs)!
}

/// macOS icon body: 824 pt squircle centered on a 1024 canvas (superellipse, n = 5).
func squircle(in r: CGRect) -> CGPath {
    let path = CGMutablePath(), n = 5.0, steps = 720
    for i in 0...steps {
        let t = Double(i) / Double(steps) * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = pow(abs(c), 2 / n) * (c < 0 ? -1 : 1), y = pow(abs(s), 2 / n) * (s < 0 ? -1 : 1)
        let p = CGPoint(x: r.midX + x * r.width / 2, y: r.midY + y * r.height / 2)
        i == 0 ? path.move(to: p) : path.addLine(to: p)
    }
    path.closeSubpath()
    return path
}

func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: 512 + x, y: 512 + y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil)
}

func fill(_ ctx: CGContext, _ path: CGPath, _ g: CGGradient) {
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    let box = path.boundingBox
    ctx.drawLinearGradient(g, start: CGPoint(x: box.midX, y: box.maxY), end: CGPoint(x: box.midX, y: box.minY), options: [])
    ctx.restoreGState()
}

/// Blue squircle, white calendar page with a coral header, today's square highlighted.
func render(size: Int) -> CGImage {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    let shape = squircle(in: CGRect(x: 100, y: 100, width: 824, height: 824))

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
    ctx.addPath(shape); ctx.setFillColor(color(0x3B6CF0)); ctx.fillPath()
    ctx.restoreGState()
    fill(ctx, shape, gradient([0x6FB1FF, 0x3B6CF0, 0x2A35B8]))
    ctx.saveGState()
    ctx.addPath(shape); ctx.clip()
    ctx.drawLinearGradient(gradient([0xFFFFFF, 0xFFFFFF], [0.3, 0]), start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 700), options: [])
    ctx.addPath(shape); ctx.setStrokeColor(color(0xFFFFFF, 0.22)); ctx.setLineWidth(6); ctx.strokePath()
    ctx.restoreGState()

    let page = rrect(-280, -270, 560, 520, 80)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: color(0x0A0626, 0.45))
    ctx.addPath(page); ctx.setFillColor(color(0xFFFFFF)); ctx.fillPath()
    ctx.restoreGState()
    fill(ctx, page, gradient([0xFFFFFF, 0xE6ECFF]))
    ctx.saveGState()
    ctx.addPath(page); ctx.clip()
    fill(ctx, CGPath(rect: CGRect(x: 232, y: 512 + 110, width: 560, height: 140), transform: nil), gradient([0xFF7A6B, 0xE8453C]))
    ctx.restoreGState()
    for x in [-150.0, 110] { // binder rings
        fill(ctx, rrect(x, 200, 40, 110, 20), gradient([0x3A3F55, 0x1D2030]))
    }
    for row in 0..<3 {
        for col in 0..<4 {
            let today = row == 1 && col == 2
            let cell = rrect(-220 + CGFloat(col) * 115, 20 - CGFloat(row) * 105, 80, 75, 20)
            fill(ctx, cell, today ? gradient([0x5AA2FF, 0x3B5BF0]) : gradient([0xD5DDF2, 0xC6D0EA]))
        }
    }
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

let args = CommandLine.arguments.dropFirst()
if args.first == "preview", let out = args.dropFirst().first {
    writePNG(render(size: args.dropFirst(2).first.flatMap { Int($0) } ?? 512), to: URL(fileURLWithPath: out))
    print("Wrote \(out)")
    exit(0)
}

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        writePNG(render(size: base * scale), to: iconset.appendingPathComponent(name))
    }
}
let resources = root.appendingPathComponent("Resources")
try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path]
try proc.run()
proc.waitUntilExit()
print(proc.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
