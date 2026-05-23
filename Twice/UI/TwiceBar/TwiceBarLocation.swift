//
//  TwiceBarLocation.swift
//  Twice
//

import SwiftUI

/// Locations where the Twice Bar can appear.
enum TwiceBarLocation: Int, CaseIterable, Identifiable {
    /// The Twice Bar will appear in different locations based on context.
    case dynamic = 0

    /// The Twice Bar will appear centered below the mouse pointer.
    case mousePointer = 1

    /// The Twice Bar will appear centered below the Twice icon.
    case twiceIcon = 2

    var id: Int { rawValue }

    /// Localized string key representation.
    var localized: LocalizedStringKey {
        switch self {
        case .dynamic: "Dynamic"
        case .mousePointer: "Mouse pointer"
        case .twiceIcon: "Twice icon"
        }
    }
}
