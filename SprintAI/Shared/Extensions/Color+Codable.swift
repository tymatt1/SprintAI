import SwiftUI

extension KeyedEncodingContainer {
    mutating func encodeColor(_ color: Color, forKey key: Key) throws {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 1
        guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            throw EncodingError.invalidValue(color, .init(codingPath: codingPath, debugDescription: "Unsupported color space"))
        }
        try encode([red, green, blue, alpha], forKey: key)
    }
}

extension KeyedDecodingContainer {
    func decodeColor(forKey key: Key) throws -> Color {
        let components = try decode([CGFloat].self, forKey: key)
        guard components.allSatisfy({ $0.isFinite && (0...1).contains($0) }) else {
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Invalid color components")
        }
        switch components.count {
        case 2: // Legacy UIColor grayscale representation.
            return Color(UIColor(white: components[0], alpha: components[1]))
        case 4:
            return Color(UIColor(red: components[0], green: components[1], blue: components[2], alpha: components[3]))
        default:
            throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Expected grayscale/alpha or RGBA")
        }
    }
}
