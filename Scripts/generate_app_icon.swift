import AppKit

// Rebuild with: swift Scripts/generate_app_icon.swift
// A sprinter inside an open timing dial, with track lanes below. iOS supplies the icon mask.
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let assets = root.appendingPathComponent("SprintAI/Resources/Assets.xcassets/AppIcon.appiconset")
let brand = root.appendingPathComponent("Docs/Brand")
try FileManager.default.createDirectory(at: brand, withIntermediateDirectories: true)

// One geometry definition drives both Core Graphics and the editable SVG.
final class VectorPath {
    let path = CGMutablePath()
    var commands: [String] = []
    func move(_ x: CGFloat, _ y: CGFloat) { path.move(to: .init(x: x, y: y)); commands.append("M\(x) \(y)") }
    func line(_ x: CGFloat, _ y: CGFloat) { path.addLine(to: .init(x: x, y: y)); commands.append("L\(x) \(y)") }
    func curve(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ x: CGFloat, _ y: CGFloat) {
        path.addCurve(to: .init(x: x, y: y), control1: .init(x: x1, y: y1), control2: .init(x: x2, y: y2))
        commands.append("C\(x1) \(y1) \(x2) \(y2) \(x) \(y)")
    }
    func close() { path.closeSubpath(); commands.append("Z") }
    var svg: String { commands.joined(separator: " ") }
}
struct Shape {
    let geometry: VectorPath
    let tone: Int
    let stroke: CGFloat?
    init(_ tone: Int, stroke: CGFloat? = nil, draw: (VectorPath) -> Void) {
        geometry = VectorPath(); self.tone = tone; self.stroke = stroke; draw(geometry)
    }
}
// Palette indexes: background, warm paper, chartreuse, quiet green.
let shapes: [Shape] = [
    Shape(3, stroke: 20) {
        $0.move(750, 748)
        $0.curve(884, 614, 868, 398, 740, 274)
        $0.curve(614, 148, 410, 145, 278, 278)
        $0.curve(146, 410, 148, 614, 278, 744)
    },
    Shape(2, stroke: 20) { $0.move(740, 274); $0.curve(782, 316, 810, 362, 824, 414) },
    Shape(1, stroke: 22) { $0.move(482, 138); $0.line(542, 138) },
    Shape(1, stroke: 16) { $0.move(512, 140); $0.line(512, 178) },
    Shape(3, stroke: 18) { $0.move(250, 464); $0.line(350, 464) },
    Shape(3, stroke: 18) { $0.move(232, 512); $0.line(320, 512) },
    // Rear arm and leg, then the forward leg. Overlapping joints form a single silhouette.
    Shape(1, stroke: 46) { $0.move(568, 403); $0.line(485, 346); $0.line(407, 374) },
    Shape(1, stroke: 62) { $0.move(505, 510); $0.line(401, 624); $0.line(277, 644) },
    Shape(1, stroke: 34) { $0.move(278, 642); $0.line(250, 670) },
    Shape(1, stroke: 64) { $0.move(512, 510); $0.line(634, 563); $0.line(557, 710) },
    Shape(1, stroke: 36) { $0.move(556, 709); $0.line(600, 730) },
    Shape(1, stroke: 42) { $0.move(584, 390); $0.line(610, 353) },
    // A tailored racing vest gives the body shape and a deliberate second green.
    Shape(2) {
        $0.move(583, 372)
        $0.curve(612, 390, 610, 413, 592, 437)
        $0.line(541, 521)
        $0.curve(525, 543, 488, 545, 468, 520)
        $0.curve(460, 505, 471, 485, 485, 463)
        $0.line(551, 388)
        $0.curve(560, 375, 573, 368, 583, 372)
        $0.close()
    },
    Shape(1, stroke: 46) { $0.move(585, 403); $0.line(655, 465); $0.line(718, 398) },
    // Slightly elongated head rather than a generic circular placeholder.
    Shape(1) {
        $0.move(665, 275)
        $0.curve(695, 292, 698, 325, 679, 350)
        $0.curve(661, 375, 632, 380, 608, 363)
        $0.curve(583, 346, 580, 317, 597, 292)
        $0.curve(613, 267, 641, 261, 665, 275)
        $0.close()
    },
    // Finish-line slash and two track lanes anchor the airborne stride.
    Shape(2) { $0.move(758, 660); $0.line(782, 660); $0.line(738, 806); $0.line(714, 806); $0.close() },
    Shape(1, stroke: 12) { $0.move(262, 786); $0.line(748, 786) },
    Shape(3, stroke: 12) { $0.move(290, 820); $0.line(720, 820) }
]

func color(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: 1)
}
func hex(_ value: UInt32) -> String { String(format: "#%06X", value) }

for (name, palette) in [
    ("1024", [UInt32(0x14663B), 0xF6F3EC, 0xC8F27A, 0x55966E]),
    ("1024-dark", [UInt32(0x142B1C), 0xF6F3EC, 0xC8F27A, 0x49765A]),
    ("1024-tinted", [UInt32(0x000000), 0xFFFFFF, 0xFFFFFF, 0x737373])
] {
    let context = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    context.setFillColor(color(palette[0]))
    context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    context.translateBy(x: 0, y: 1024)
    context.scaleBy(x: 1, y: -1)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    for shape in shapes {
        context.addPath(shape.geometry.path)
        if let width = shape.stroke {
            context.setLineWidth(width)
            context.setStrokeColor(color(palette[shape.tone]))
            context.strokePath()
        } else {
            context.setFillColor(color(palette[shape.tone]))
            context.fillPath()
        }
    }
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    try bitmap.representation(using: .png, properties: [:])!.write(to: assets.appendingPathComponent("\(name).png"))
    if name == "1024" {
        let paths = shapes.map { shape in
            let paint = hex(palette[shape.tone])
            let style = shape.stroke.map { "fill=\"none\" stroke=\"\(paint)\" stroke-width=\"\($0)\"" } ?? "fill=\"\(paint)\""
            return "  <path d=\"\(shape.geometry.svg)\" \(style)/>"
        }.joined(separator: "\n")
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" stroke-linecap="round" stroke-linejoin="round">
          <title>SprintAI — sprinter, timing dial, and finish line</title>
          <rect width="1024" height="1024" fill="\(hex(palette[0]))"/>
        \(paths)
        </svg>
        """
        try svg.write(to: brand.appendingPathComponent("app-icon.svg"), atomically: true, encoding: .utf8)
    }
}
print("Generated standard, dark, and tinted SprintAI icons.")
