//
//  CircleSymbol.swift
//  SprintTimer
//
//  Created by Matthew Tybur on 10/7/24.
//

import SwiftUI

struct CircleSymbol: View {
    var color: Color
    var isSelected: Bool
    var size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)
            if isSelected {
                Circle()
                    .stroke(color, lineWidth: 2)
                    .frame(width: size, height: size)
            }
        }
    }
}
