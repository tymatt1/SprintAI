//
//  AxisDomainHelper.swift
//  SprintTimer
//
//  Created by Matthew Tybur on 10/7/24.
//

import SwiftUI

func yAxisDomain(records: [SprintTimeRecord]) -> ClosedRange<Double> {
    if records.isEmpty {
        return 0...10
    } else {
        let times = records.compactMap { $0.time }
        guard let minTime = times.min(), let maxTime = times.max() else {
            return 0...10
        }

        var lowerBound: Double
        var upperBound: Double

        if minTime == maxTime {
            lowerBound = max(0, minTime - 5)
            upperBound = minTime + 5
        } else {
            let padding = (maxTime - minTime) * 0.1
            lowerBound = max(0, minTime - padding)
            upperBound = maxTime + padding
        }

        return lowerBound...upperBound
    }
}

func xAxisDomain(records: [SprintTimeRecord]) -> ClosedRange<Date> {
    if records.isEmpty {
        let now = Date()
        return now...now.addingTimeInterval(60 * 60)
    } else {
        let dates = records.compactMap { $0.date }
        guard let minDate = dates.min(), let maxDate = dates.max() else {
            let now = Date()
            return now...now.addingTimeInterval(60 * 60)
        }

        var lowerBound: Date
        var upperBound: Date

        if minDate == maxDate {
            lowerBound = minDate.addingTimeInterval(-30 * 60)
            upperBound = minDate.addingTimeInterval(30 * 60)
        } else {
            let interval = maxDate.timeIntervalSince(minDate)
            let padding = interval * 0.1
            lowerBound = minDate.addingTimeInterval(-padding)
            upperBound = maxDate.addingTimeInterval(padding)
        }

        return lowerBound...upperBound
    }
}
