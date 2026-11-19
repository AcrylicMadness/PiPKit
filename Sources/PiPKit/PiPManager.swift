import UIKit
import SwiftUI

/// Owns one floating PiP presentation in a window scene.
@MainActor
public final class PiPManager {
    private var pipWindow: PiPWindow?
    private(set) weak var originalView: UIView?
    private var isClosing = false

    public var isPresenting: Bool { pipWindow != nil }
    public var isTucked: Bool { pipWindow?.isTucked ?? false }

    public init() {}

    private lazy var placeholderView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        let label = UILabel()
        label.numberOfLines = 0
        label.text = "Moved to PiP"
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Presents the actual, unattached view. No source view or placeholder is required.
    @discardableResult
    public func presentPiP(content: UIView, in scene: UIWindowScene,
                           size: CGSize = CGSize(width: 200, height: 100)) -> Bool {
        guard content.superview == nil, content.window == nil else { return false }
        let controller = UIViewController()
        controller.view = content
        return present(controller: controller, in: scene, size: size)
    }

    /// Hosts live SwiftUI content, including its state and interactive controls.
    @discardableResult
    public func presentPiP<Content: View>(content: Content, in scene: UIWindowScene,
                                        size: CGSize = CGSize(width: 200, height: 100)) -> Bool {
        let controller = UIHostingController(rootView: content)
        controller.view.backgroundColor = .clear
        return present(controller: controller, in: scene, size: size)
    }

    /// Closes an existing presentation, or presents the supplied standalone content.
    @discardableResult
    public func togglePiP(content: UIView, in scene: UIWindowScene,
                          size: CGSize = CGSize(width: 200, height: 100)) -> Bool {
        guard !isClosing else { return false }
        if isPresenting { closePiP(); return true }
        return presentPiP(content: content, in: scene, size: size)
    }

    @discardableResult
    public func togglePiP<Content: View>(content: Content, in scene: UIWindowScene,
                                       size: CGSize = CGSize(width: 200, height: 100)) -> Bool {
        guard !isClosing else { return false }
        if isPresenting { closePiP(); return true }
        return presentPiP(content: content, in: scene, size: size)
    }

    private func present(controller: UIViewController, in scene: UIWindowScene, size: CGSize,
                         sourceFrame: CGRect? = nil, bounds: CGRect? = nil,
                         insets: UIEdgeInsets? = nil) -> Bool {
        guard pipWindow == nil, !isClosing, size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else { return false }
        let insets = insets ?? (scene.windows.first(where: \.isKeyWindow)?.safeAreaInsets ?? .zero).extendedBy(16)
        let window = PiPWindow(windowScene: scene, contentController: controller, size: size,
                               inBounds: bounds ?? scene.coordinateSpace.bounds, withInsets: insets)
        pipWindow = window
        window.present(from: sourceFrame)
        return true
    }

    /// Preserves the attached-view convenience API by displaying a copy of the source.
    public func presentPiP(withView view: UIView, andBounds bounds: CGRect, andInsets insets: UIEdgeInsets) {
        guard pipWindow == nil, let scene = view.window?.windowScene,
              let copy: UIView = view.copyView() else { return }
        let controller = UIViewController()
        controller.view = copy
        let sourceFrame = view.convert(view.bounds, to: scene.coordinateSpace)
        guard present(controller: controller, in: scene, size: CGSize(width: 200, height: 100),
                      sourceFrame: sourceFrame, bounds: bounds, insets: insets) else { return }
        originalView = view
        view.addSubview(placeholderView)
        NSLayoutConstraint.activate([
            placeholderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            placeholderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            placeholderView.topAnchor.constraint(equalTo: view.topAnchor),
            placeholderView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    public func changePiPBounds(newBounds bounds: CGRect, andInsets insets: UIEdgeInsets) {
        pipWindow?.changeSuperviewBounds(newBounds: bounds, andInsets: insets)
    }

    func contains(_ view: UIView) -> Bool {
        originalView === view || pipWindow?.contentController.viewIfLoaded === view
    }

    public func closePiP(withView view: UIView) {
        guard contains(view) else { return }
        closePiP()
    }

    /// Closes standalone or attached content, including a tucked presentation.
    public func closePiP() {
        guard let window = pipWindow, !isClosing else { return }
        isClosing = true
        var sourceFrame: CGRect?
        if let source = originalView, let scene = window.windowScene, source.window?.windowScene === scene {
            sourceFrame = source.convert(source.bounds, to: scene.coordinateSpace)
        }
        window.close(to: sourceFrame) { [weak self, weak window] in
            guard let self = self, let window = window, self.pipWindow === window else { return }
            self.dismissPiP()
        }
    }

    public func restorePiP() {
        guard !isClosing else { return }
        pipWindow?.restore()
    }

    /// Immediately releases content and removes any source placeholder.
    public func dismissPiP() {
        placeholderView.removeFromSuperview()
        pipWindow?.tearDown()
        pipWindow = nil
        originalView = nil
        isClosing = false
    }
}
