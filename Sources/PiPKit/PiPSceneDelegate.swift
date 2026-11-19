import UIKit

/// Provides a scene's PiP manager to the view convenience methods.
@MainActor
public protocol PiPSceneDelegate: UIWindowSceneDelegate {
    var pipManager: PiPManager { get }
}
