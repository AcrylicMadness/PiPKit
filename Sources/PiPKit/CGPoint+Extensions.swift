//
//  CGPoint+Extensions.swift
//  PiPKit
//
//  Created by Кирилл Аверкиев on 19.06.2023.
//

import UIKit

extension CGPoint {
    func distanceSquared(toPoint point: CGPoint) -> CGFloat {
        (x - point.x) * (x - point.x) + (y - point.y) * (y - point.y)
    }
    
    func distance(toPoint point: CGPoint) -> CGFloat {
        sqrt(distanceSquared(toPoint: point))
    }
    
    func absoluteDistance(toPoint point: CGPoint) -> CGFloat {
        abs(distance(toPoint: point))
    }
}
