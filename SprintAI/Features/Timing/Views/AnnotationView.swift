//
//  AnnotationView.swift
//  SprintTimer
//
//  Created by Matthew Tybur on 10/7/24.
//

import SwiftUI

struct AnnotationView: View {
    let record: SprintTimeRecord

    var body: some View {
        let time = record.time
        Group {
            VStack(spacing: 5) {
                ZStack {
                    Text("Time: \(time, specifier: "%.2f")s")
                        .font(.headline)
                        .bold()
                        .foregroundColor(.black)
                        .offset(x: 1, y: 1)
                    Text("Time: \(time, specifier: "%.2f")s")
                        .font(.headline)
                        .bold()
                        .foregroundColor(.black)
                        .offset(x: -1, y: -1)

                    Text("Time: \(time, specifier: "%.2f")s")
                        .font(.headline)
                        .bold()
                        .foregroundStyle(LinearGradient(
                            gradient: Gradient(colors: [
                                record.color.opacity(1.0),
                                record.color.opacity(0.6)
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                }
            }
            .padding(8)
            .background(Color.clear)
            .cornerRadius(8)
            .shadow(radius: 5)
            .offset(y: -5)
        }
    }
}
