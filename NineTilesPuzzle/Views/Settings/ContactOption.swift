//
//  ContactOption.swift
//  NineTilesPuzzle
//
//  Created by Filippo Cilia on 8/5/26.
//

import Foundation

enum ContactOption: String, CaseIterable, Identifiable {
    case reportBug
    case requestFeature
    case otherEnquiry

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reportBug: "Report a Bug"
        case .requestFeature: "Request a Feature"
        case .otherEnquiry: "Other Enquiry"
        }
    }

    var subject: String {
        switch self {
        case .reportBug: "Nine Tiles Puzzle: Bug Report"
        case .requestFeature: "Nine Tiles Puzzle: Feature Idea"
        case .otherEnquiry: "Nine Tiles Puzzle: Enquiry"
        }
    }

    var body: String {
        switch self {
        case .reportBug: "Please describe the bug you encountered, including steps to reproduce it and screenshots if possible."
        case .requestFeature, .otherEnquiry: ""
        }
    }
}
