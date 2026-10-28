import SwiftUI

struct OutlinedText: View {
    var text: String
    var font: Font
    var weight: Font.Weight = .regular
    var fillColor: Color = .white
    var strokeColor: Color = .blue
    var lineWidth: CGFloat = 1

    var body: some View {
        ZStack {
            // Stroke
            Text(text)
                .font(font)
                .fontWeight(weight)
                .foregroundColor(strokeColor)
                .offset(x: -lineWidth, y: -lineWidth)
            Text(text)
                .font(font)
                .fontWeight(weight)
                .foregroundColor(strokeColor)
                .offset(x: lineWidth, y: -lineWidth)
            Text(text)
                .font(font)
                .fontWeight(weight)
                .foregroundColor(strokeColor)
                .offset(x: -lineWidth, y: lineWidth)
            Text(text)
                .font(font)
                .fontWeight(weight)
                .foregroundColor(strokeColor)
                .offset(x: lineWidth, y: lineWidth)
            // Fill
            Text(text)
                .font(font)
                .fontWeight(weight)
                .foregroundColor(fillColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

struct OutlinedImage: View {
    var systemName: String
    var size: CGFloat
    var fillColor: Color = .white
    var strokeColor: Color = .blue
    var lineWidth: CGFloat = 2

    var body: some View {
        ZStack {
            // Stroke
            Image(systemName: systemName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundColor(strokeColor)
                .offset(x: -lineWidth, y: -lineWidth)
            Image(systemName: systemName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundColor(strokeColor)
                .offset(x: lineWidth, y: -lineWidth)
            Image(systemName: systemName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundColor(strokeColor)
                .offset(x: -lineWidth, y: lineWidth)
            Image(systemName: systemName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundColor(strokeColor)
                .offset(x: lineWidth, y: lineWidth)
            // Fill
            Image(systemName: systemName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundColor(fillColor)
        }
        .accessibilityHidden(true)
    }
}
