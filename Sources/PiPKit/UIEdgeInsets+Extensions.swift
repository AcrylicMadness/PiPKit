import UIKit

public extension UIEdgeInsets {
    func extendedBy(_ value: CGFloat) -> UIEdgeInsets {
        UIEdgeInsets(top: top + value, left: left + value, bottom: bottom + value, right: right + value)
    }
}
