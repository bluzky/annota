//
//  HitTestResult.swift
//  texttool
//
//  Created by Claude on 2/18/26.
//

import Foundation

/// Represents the corners of a bounding box
enum Corner: String, CaseIterable, Codable, Hashable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    /// Returns the opposite corner
    var opposite: Corner {
        switch self {
        case .topLeft: return .bottomRight
        case .topRight: return .bottomLeft
        case .bottomLeft: return .topRight
        case .bottomRight: return .topLeft
        }
    }
}

/// Represents the edges of a bounding box
enum Edge: String, CaseIterable, Codable, Hashable {
    case top
    case right
    case bottom
    case left

    /// Returns the opposite edge
    var opposite: Edge {
        switch self {
        case .top: return .bottom
        case .right: return .left
        case .bottom: return .top
        case .left: return .right
        }
    }

    /// Returns whether this edge is horizontal (top/bottom)
    var isHorizontal: Bool {
        self == .top || self == .bottom
    }

    /// Returns whether this edge is vertical (left/right)
    var isVertical: Bool {
        self == .left || self == .right
    }
}

/// Result of a hit test on a canvas object
enum HitTestResult: Hashable {
    /// Hit on the body/interior of the object
    case body

    /// Hit on an edge of the object's bounding box
    case edge(Edge)

    /// Hit on a corner of the object's bounding box
    case corner(Corner)

    /// Hit on the rotation handle
    case rotationHandle

    /// Hit on a control point (for paths/curves)
    case controlPoint(index: Int)

    /// Hit on the text label area
    case label
}

// MARK: - HitTestResult Extensions

extension HitTestResult {
    /// Returns true if this result represents a resize handle (edge or corner)
    var isResizeHandle: Bool {
        switch self {
        case .edge, .corner:
            return true
        default:
            return false
        }
    }

    /// Returns true if this result represents interaction with the object content
    var isContentHit: Bool {
        switch self {
        case .body, .label:
            return true
        default:
            return false
        }
    }
}
