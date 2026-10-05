// Renders the DMG window background (660×400 pt) at 1x and 2x:
//   swift scripts/make-dmg-background.swift <out-dir>   → background.png, background@2x.png
// The icons sit at x = 180 and 480, y = 215 (see build.sh); the arrow runs between them.
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let width = 660.0, height = 400.0
let purple = CGColor(srgbRed: 0x45 / 255, green: 0x14 / 255, blue: 0x84 / 255, alpha: 1) // Kumpan purple

func render(scale: CGFloat) -> CGImage {
    let ctx = CGContext(data: nil, width: Int(width * scale), height: Int(height * scale), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: scale, y: scale)
    // Flip to a top-left origin, like Finder's icon coordinates.
    ctx.translateBy(x: 0, y: height)
    ctx.scaleBy(x: 1, y: -1)

    // Lavender wash, lighter at the top.
    let wash = CGGradient(colorsSpace: nil, colors: [
        CGColor(srgbRed: 0.97, green: 0.965, blue: 1, alpha: 1),
        CGColor(srgbRed: 0.86, green: 0.85, blue: 1, alpha: 1),
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(wash, start: .zero, end: CGPoint(x: 0, y: height), options: [])

    // Kumpan-logo geometry in the corners: a circle and a quarter disc, barely there.
    ctx.setFillColor(CGColor(srgbRed: 0.27, green: 0.08, blue: 0.52, alpha: 0.06))
    ctx.fillEllipse(in: CGRect(x: -70, y: 250, width: 220, height: 220))
    let quarter = CGMutablePath()
    quarter.move(to: CGPoint(x: width, y: 0))
    quarter.addLine(to: CGPoint(x: width - 190, y: 0))
    quarter.addArc(center: CGPoint(x: width, y: 0), radius: 190, startAngle: .pi, endAngle: .pi / 2, clockwise: true)
    quarter.closeSubpath()
    ctx.addPath(quarter)
    ctx.fillPath()

    // Arrow from the app to Applications: a trail of growing dots, then a rounded chevron.
    ctx.setFillColor(purple)
    let y = 215.0
    for (i, x) in [282.0, 304, 328, 354].enumerated() {
        let r = 3.0 + Double(i) * 1.2
        ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
    }
    ctx.setStrokeColor(purple)
    ctx.setLineWidth(7)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: 370, y: y - 20))
    ctx.addLine(to: CGPoint(x: 390, y: y))
    ctx.addLine(to: CGPoint(x: 370, y: y + 20))
    ctx.strokePath()

    // Heading. CoreText draws in a y-up space, so flip back locally.
    let font = CTFontCreateUIFontForLanguage(.system, 22, nil)!
    let bold = CTFontCreateCopyWithSymbolicTraits(font, 22, nil, .traitBold, .traitBold) ?? font
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "Drag CalendarBar into Applications", attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): bold,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): purple,
    ]))
    let textWidth = CTLineGetTypographicBounds(line, nil, nil, nil)
    ctx.saveGState()
    ctx.translateBy(x: (width - textWidth) / 2, y: 78)
    ctx.scaleBy(x: 1, y: -1)
    ctx.textPosition = .zero
    CTLineDraw(line, ctx)
    ctx.restoreGState()
    return ctx.makeImage()!
}

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
for (scale, name) in [(1.0, "background.png"), (2.0, "background@2x.png")] {
    let dest = CGImageDestinationCreateWithURL(out.appendingPathComponent(name) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    // 72 dpi × scale, so Finder treats the 2x file as Retina.
    CGImageDestinationAddImage(dest, render(scale: scale), [kCGImagePropertyDPIWidth: 72 * scale, kCGImagePropertyDPIHeight: 72 * scale] as CFDictionary)
    CGImageDestinationFinalize(dest)
}
