//
//  SprintTimeRecord.swift
//  SprintTimer
//
//  Created by Matthew Tybur on 10/7/24.
//

import SwiftUI

struct SprintTimeRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    let time: TimeInterval
    let color: Color

    // Coding keys for encoding/decoding the Color
    enum CodingKeys: CodingKey {
        case id, date, time, color
    }

    // Encode the color
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(time, forKey: .time)
        try container.encodeColor(color, forKey: .color)
    }

    // Decode the color
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        time = try container.decode(TimeInterval.self, forKey: .time)
        color = try container.decodeColor(forKey: .color)
    }

    // Initializer for creating new records
    init(id: UUID = UUID(), date: Date = Date(), time: TimeInterval, color: Color) {
        self.id = id
        self.date = date
        self.time = time
        self.color = color
    }
}
