//
//  Formatters.swift
//  BeatTheOdds
//
//  Created by Alex Bradshaw on 09.03.26.
//
import Foundation

func formatNumber(_ value: Double) -> String {
    let absValue = abs(value)

    if absValue >= 1_000_000_000_000 {
        return String(format: "%.1fT", value / 1_000_000_000_000)
    } else if absValue >= 1_000_000_000 {
        return String(format: "%.1fB", value / 1_000_000_000)
    } else if absValue >= 1_000_000 {
        return String(format: "%.1fM", value / 1_000_000)
    } else if absValue >= 1_000 {
        return String(format: "%.1fK", value / 1_000)
    } else {
        return String(format: "%.0f", value)
    }
}
