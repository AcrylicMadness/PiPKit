//
//  PiPCorner.swift
//  PiPKit
//
//  Created by Кирилл Аверкиев on 19.06.2023.
//

import UIKit

enum PiPCorner: CaseIterable, Equatable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    
    func stickyPoint(forFrame frame: CGRect, inBounds bounds: CGRect, withInsets insets: UIEdgeInsets) -> CGPoint {
        switch self {
        case .topLeft:
            return CGPoint(x: bounds.minX + insets.left, y: bounds.minY + insets.top)
        case .topRight:
            return CGPoint(x: bounds.maxX - insets.right - frame.width, y: bounds.minY + insets.top)
        case .bottomLeft:
            return CGPoint(x: bounds.minX + insets.left, y: bounds.maxY - frame.height - insets.bottom)
        case .bottomRight:
            return CGPoint(x: bounds.maxX - frame.width - insets.right, y: bounds.maxY - frame.height - insets.bottom)
        }
    }
    
    func delta(fromPoint pont: CGPoint, withFrame frame: CGRect, inBounds bounds: CGRect, andInsets insets: UIEdgeInsets) -> CGFloat {
        pont.absoluteDistance(toPoint: stickyPoint(forFrame: frame, inBounds: bounds, withInsets: insets))
    }
}
