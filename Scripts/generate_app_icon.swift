import AppKit

// Rebuild with: swift Scripts/generate_app_icon.swift
// A forward-leaning track S with cut terminals and a chartreuse racing tip.
// iOS supplies the outer icon mask.
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let assets = root.appendingPathComponent("SprintAI/Resources/Assets.xcassets/AppIcon.appiconset")
let brand = root.appendingPathComponent("Docs/Brand")
try FileManager.default.createDirectory(at: brand, withIntermediateDirectories: true)

let track = CGMutablePath()
track.move(to: CGPoint(x: 736, y: 300))
track.addLine(to: CGPoint(x: 430, y: 300))
track.addCurve(to: CGPoint(x: 430, y: 512), control1: CGPoint(x: 284, y: 300), control2: CGPoint(x: 284, y: 512))
track.addLine(to: CGPoint(x: 594, y: 512))
track.addCurve(to: CGPoint(x: 594, y: 724), control1: CGPoint(x: 740, y: 512), control2: CGPoint(x: 740, y: 724))
track.addLine(to: CGPoint(x: 288, y: 724))
let pathData = "M736 300H430C284 300 284 512 430 512H594C740 512 740 724 594 724H288"

func polygon(_ points: [CGPoint]) -> CGPath {
    let path = CGMutablePath()
    path.addLines(between: points)
    path.closeSubpath()
    return path
}
let racingTip = polygon([.init(x: 624, y: 224), .init(x: 736, y: 224),
                         .init(x: 736, y: 288), .init(x: 588, y: 288)])
let upperCut = polygon([.init(x: 736, y: 224), .init(x: 736, y: 376), .init(x: 708, y: 376)])
let lowerCut = polygon([.init(x: 288, y: 648), .init(x: 316, y: 648), .init(x: 288, y: 800)])

func color(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}

for (name, background, foreground, accent) in [
    ("1024", UInt32(0x14663B), UInt32(0xF6F3EC), UInt32(0xC8F27A)),
    ("1024-dark", UInt32(0x142B1C), UInt32(0xF6F3EC), UInt32(0xC8F27A)),
    ("1024-tinted", UInt32(0x000000), UInt32(0xFFFFFF), UInt32(0xFFFFFF))
] {
    let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(color(background))
    context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    context.translateBy(x: 0, y: 1024)
    context.scaleBy(x: 1, y: -1)
    // Shear around the center rather than rotate: horizontal lanes stay level.
    context.concatenate(CGAffineTransform(a: 1, b: 0, c: -0.18, d: 1, tx: 92.16, ty: 0))
    context.setLineCap(.butt)
    context.setLineJoin(.round)
    for (width, stroke) in [(CGFloat(152), foreground), (CGFloat(24), background)] {
        context.addPath(track)
        context.setLineWidth(width)
        context.setStrokeColor(color(stroke))
        context.strokePath()
    }
    context.setFillColor(color(accent))
    context.addPath(racingTip)
    context.fillPath()
    context.setFillColor(color(background))
    context.addPath(upperCut)
    context.addPath(lowerCut)
    context.fillPath()
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    try bitmap.representation(using: .png, properties: [:])!.write(to: assets.appendingPathComponent("\(name).png"))
    if name == "1024" {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
          <title>SprintAI — racing track S</title>
          <rect width="1024" height="1024" fill="#14663B"/>
          <g transform="matrix(1 0 -.18 1 92.16 0)">
            <path d="\(pathData)" fill="none" stroke="#F6F3EC" stroke-width="152"/>
            <path d="\(pathData)" fill="none" stroke="#14663B" stroke-width="24"/>
            <path d="M624 224H736V288H588Z" fill="#C8F27A"/>
            <path d="M736 224V376H708Z M288 648H316L288 800Z" fill="#14663B"/>
          </g>
        </svg>
        """
        try svg.write(to: brand.appendingPathComponent("app-icon.svg"), atomically: true, encoding: .utf8)
    }
}
print("Generated standard, dark, and tinted SprintAI icons.")
