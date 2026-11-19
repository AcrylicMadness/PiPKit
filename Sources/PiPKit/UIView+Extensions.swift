//
//  UIView+Extensions.swift
//  PiPKit
//
//  Created by Кирилл Аверкиев on 21.05.2021.
//

import Foundation
import UIKit

extension UIView {
    private var pipManager: PiPManager? {
        (window?.windowScene?.delegate as? PiPSceneDelegate)?.pipManager
    }

    public var isInPiP: Bool {
        pipManager?.contains(self) ?? false
    }

    public func moveToPiP(withBounds bounds: CGRect, andInsets insets: UIEdgeInsets) {
        pipManager?.presentPiP(withView: self, andBounds: bounds, andInsets: insets)
    }
    
    public func closePiP() {
        pipManager?.closePiP(withView: self)
    }
    
    public func changePiPBounds(newBounds bounds: CGRect, andInsets insets: UIEdgeInsets) {
        pipManager?.changePiPBounds(newBounds: bounds, andInsets: insets)
    }
    
    func copyView<T: UIView>() -> T? {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: false)
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            // UIKit views use NSCoding. Only decode the archive created just above.
            unarchiver.requiresSecureCoding = false
            defer { unarchiver.finishDecoding() }
            return unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? T
        } catch {
            print("Unable to copy view for PiP: \(error)")
            return nil
        }
    }
}
