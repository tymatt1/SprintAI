import AppKit

// Rebuild with: swift Scripts/generate_app_icon.swift
// Two continuous track lanes form an S; iOS supplies the outer icon mask.
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

func color(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}

for (name, background, foreground) in [
    ("1024", UInt32(0x14663B), UInt32(0xF6F3EC)),
    ("1024-dark", UInt32(0x142B1C), UInt32(0xF6F3EC)),
    ("1024-tinted", UInt32(0x000000), UInt32(0xFFFFFF))
] {
    let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(color(background))
    context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    context.translateBy(x: 0, y: 1024)
    context.scaleBy(x: 1, y: -1)
    context.setLineCap(.butt)
    context.setLineJoin(.round)
    for (width, stroke) in [(CGFloat(152), foreground), (CGFloat(24), background)] {
        context.addPath(track)
        context.setLineWidth(width)
        context.setStrokeColor(color(stroke))
        context.strokePath()
    }
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    try bitmap.representation(using: .png, properties: [:])!.write(to: assets.appendingPathComponent("\(name).png"))
    if name == "1024" {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">
          <title>SprintAI — track S</title>
          <rect width="1024" height="1024" fill="#14663B"/>
          <path d="\(pathData)" fill="none" stroke="#F6F3EC" stroke-width="152"/>
          <path d="\(pathData)" fill="none" stroke="#14663B" stroke-width="24"/>
        </svg>
        """
        try svg.write(to: brand.appendingPathComponent("app-icon.svg"), atomically: true, encoding: .utf8)
    }
}
print("Generated standard, dark, and tinted SprintAI icons.")
