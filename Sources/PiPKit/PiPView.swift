import UIKit

/// A transparent scene-sized window. Only the floating content and pull tab take touches.
final class PiPWindow: UIWindow {
    private let containerController = PiPContainerController()
    private let floatingView = UIView()
    private let clippingView = UIView()
    private let pullTab = PiPPullTab(type: .system)
    let contentController: UIViewController
    private var geometry: PiPGeometry
    private let requestedSize: CGSize
    private var contentSize: CGSize
    private var placement: PiPPlacement = .corner(.topLeft)
    private var currentCorner: PiPCorner = .topLeft
    private var dragStartFrame = CGRect.zero
    private var dragStartPlacement: PiPPlacement = .corner(.topLeft)
    private var isDragging = false
    private var isClosing = false
    private var pinchStartSize = CGSize.zero
    private var sceneBounds: CGRect
    private var systemInsets: UIEdgeInsets
    private var edgeMargins: UIEdgeInsets
    private var rootSizeConstraints: [NSLayoutConstraint] = []
    private var contentUsedAutoresizingMask = true

    var isTucked: Bool {
        if case .tucked = placement { return true }
        return false
    }

    override var canBecomeKey: Bool { false }

    init(windowScene: UIWindowScene, contentController: UIViewController, size: CGSize,
         inBounds bounds: CGRect, withInsets insets: UIEdgeInsets) {
        self.contentController = contentController
        let safeAreaInsets = windowScene.windows.first(where: \.isKeyWindow)?.safeAreaInsets ?? .zero
        self.geometry = PiPGeometry(bounds: bounds, insets: insets, safeAreaInsets: safeAreaInsets)
        self.requestedSize = size
        self.contentSize = geometry.fittedSize(size)
        self.sceneBounds = windowScene.coordinateSpace.bounds
        self.systemInsets = safeAreaInsets
        self.edgeMargins = UIEdgeInsets(top: max(0, insets.top - systemInsets.top),
                                        left: max(0, insets.left - systemInsets.left),
                                        bottom: max(0, insets.bottom - systemInsets.bottom),
                                        right: max(0, insets.right - systemInsets.right))
        super.init(windowScene: windowScene)
        frame = sceneBounds
        backgroundColor = .clear
        windowLevel = .alert
        accessibilityIdentifier = "PiPKit.window"
        rootViewController = containerController
        containerController.loadViewIfNeeded()
        containerController.view.backgroundColor = .clear
        setupContent()
        setupPullTab()
        containerController.onLayout = { [weak self] in self?.updateSceneGeometry() }
    }

    required init?(coder: NSCoder) {
        fatalError("Create PiP windows with a window scene and content controller.")
    }

    private func setupContent() {
        floatingView.accessibilityIdentifier = "PiPKit.content"
        floatingView.layer.shadowColor = UIColor.black.cgColor
        floatingView.layer.shadowOpacity = 0.25
        floatingView.layer.shadowRadius = 10
        floatingView.layer.shadowOffset = .zero
        clippingView.layer.cornerRadius = 12
        clippingView.clipsToBounds = true
        clippingView.frame = floatingView.bounds
        clippingView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        floatingView.addSubview(clippingView)
        containerController.view.addSubview(floatingView)

        containerController.addChild(contentController)
        let content = contentController.view!
        // The host controls the root view's size; preserve constraints on its children.
        rootSizeConstraints = content.constraints.filter {
            $0.firstItem === content && $0.secondItem == nil &&
                ($0.firstAttribute == .width || $0.firstAttribute == .height)
        }
        NSLayoutConstraint.deactivate(rootSizeConstraints)
        contentUsedAutoresizingMask = content.translatesAutoresizingMaskIntoConstraints
        content.translatesAutoresizingMaskIntoConstraints = false
        clippingView.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: clippingView.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: clippingView.trailingAnchor),
            content.topAnchor.constraint(equalTo: clippingView.topAnchor),
            content.bottomAnchor.constraint(equalTo: clippingView.bottomAnchor)
        ])
        contentController.didMove(toParent: containerController)
        addPan(to: floatingView)
        floatingView.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(pinch(_:))))
        floatingView.addInteraction(UIPointerInteraction(delegate: self))
    }

    private func setupPullTab() {
        pullTab.accessibilityIdentifier = "PiPKit.restoreTab"
        pullTab.accessibilityLabel = "Restore Picture in Picture"
        pullTab.accessibilityHint = "Double-tap or drag toward the center of the screen."
        var configuration = UIButton.Configuration.plain()
        configuration.baseForegroundColor = .label
        configuration.contentInsets = .zero
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        configuration.background.visualEffect = UIBlurEffect(style: .systemMaterial)
        pullTab.configuration = configuration
        pullTab.layer.cornerRadius = 12
        pullTab.clipsToBounds = true
        pullTab.addTarget(self, action: #selector(restore), for: .touchUpInside)
        pullTab.alpha = 0
        containerController.view.addSubview(pullTab)
        addPan(to: pullTab)
    }

    private func addPan(to view: UIView) {
        let recognizer = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
        recognizer.maximumNumberOfTouches = 1
        view.addGestureRecognizer(recognizer)
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01 else { return nil }
        let tabPoint = pullTab.convert(point, from: self)
        if pullTab.alpha > 0.01 && pullTab.point(inside: tabPoint, with: event) {
            return pullTab.hitTest(tabPoint, with: event) ?? pullTab
        }
        let contentPoint = floatingView.convert(point, from: self)
        guard !floatingView.isHidden, floatingView.point(inside: contentPoint, with: event) else { return nil }
        return super.hitTest(point, with: event)
    }

    func present(from sourceFrame: CGRect? = nil) {
        floatingView.frame = sourceFrame ?? geometry.frame(for: currentCorner, size: contentSize)
        floatingView.alpha = sourceFrame == nil ? 0 : 1
        isHidden = false
        containerController.view.layoutIfNeeded()
        settle(at: .corner(currentCorner), animated: true)
    }

    func changeSuperviewBounds(newBounds bounds: CGRect, andInsets insets: UIEdgeInsets) {
        // A source view may report its new insets before this overlay lays out.
        if let mainWindow = windowScene?.windows.first(where: { $0 !== self && $0.isKeyWindow }) {
            systemInsets = mainWindow.safeAreaInsets
        }
        guard bounds.width > 0, bounds.height > 0,
              bounds != geometry.bounds || insets != geometry.insets || systemInsets != geometry.safeAreaInsets else { return }
        geometry = PiPGeometry(bounds: bounds, insets: insets, safeAreaInsets: systemInsets)
        edgeMargins = UIEdgeInsets(top: max(0, insets.top - systemInsets.top),
                                   left: max(0, insets.left - systemInsets.left),
                                   bottom: max(0, insets.bottom - systemInsets.bottom),
                                   right: max(0, insets.right - systemInsets.right))
        contentSize = geometry.fittedSize(contentSize)
        if !isDragging && !isClosing { settle(at: placement, animated: false) }
    }

    private func updateSceneGeometry() {
        guard let scene = windowScene else { return }
        let bounds = scene.coordinateSpace.bounds
        let insets = scene.windows.first(where: { $0 !== self && $0.isKeyWindow })?.safeAreaInsets ?? .zero
        guard bounds != sceneBounds || insets != systemInsets else { return }
        sceneBounds = bounds
        systemInsets = insets
        frame = bounds
        changeSuperviewBounds(newBounds: bounds,
                              andInsets: UIEdgeInsets(top: insets.top + edgeMargins.top,
                                                      left: insets.left + edgeMargins.left,
                                                      bottom: insets.bottom + edgeMargins.bottom,
                                                      right: insets.right + edgeMargins.right))
    }

    private func configureTab(edge: PiPEdge, centerY: CGFloat) {
        pullTab.frame = geometry.tabFrame(edge: edge, centerY: centerY)
        var configuration = pullTab.configuration
        configuration?.image = UIImage(systemName: edge == .left ? "chevron.right" : "chevron.left")
        pullTab.configuration = configuration
        pullTab.layer.maskedCorners = edge == .left ? [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
                                                    : [.layerMinXMinYCorner, .layerMinXMaxYCorner]
    }

    private func settle(at target: PiPPlacement, animated: Bool, velocity: CGPoint = .zero) {
        placement = target
        floatingView.isHidden = false
        let targetFrame: CGRect
        let tabAlpha: CGFloat
        switch target {
        case .corner(let corner):
            currentCorner = corner
            targetFrame = geometry.frame(for: corner, size: contentSize)
            tabAlpha = 0
        case .tucked(let edge, let centerY):
            targetFrame = geometry.tuckedFrame(edge: edge, centerY: centerY, size: contentSize)
            currentCorner = geometry.nearestCorner(to: CGRect(x: edge == .left ? geometry.visibleBounds.minX
                : geometry.visibleBounds.maxX - contentSize.width, y: targetFrame.minY,
                width: contentSize.width, height: contentSize.height))
            configureTab(edge: edge, centerY: targetFrame.midY)
            tabAlpha = 1
        }
        let animations = {
            self.floatingView.frame = targetFrame
            self.floatingView.alpha = 1
            self.clippingView.layer.cornerRadius = 12
            self.pullTab.alpha = tabAlpha
            self.floatingView.layoutIfNeeded()
        }
        let completion: (Bool) -> Void = { [weak self] _ in
            guard let self = self, !self.isDragging, self.placement == target else { return }
            self.floatingView.isHidden = self.isTucked
        }
        if animated {
            let delta = CGPoint(x: targetFrame.minX - floatingView.frame.minX,
                                y: targetFrame.minY - floatingView.frame.minY)
            let distanceSquared = delta.x * delta.x + delta.y * delta.y
            let initialVelocity = distanceSquared > 1
                ? min(12, max(0, (velocity.x * delta.x + velocity.y * delta.y) / distanceSquared)) : 0
            UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.85,
                           initialSpringVelocity: initialVelocity,
                           options: [.beginFromCurrentState, .allowUserInteraction],
                           animations: animations, completion: completion)
        } else {
            animations()
            completion(true)
        }
    }

    @objc func restore() {
        guard isTucked, !isClosing else { return }
        settle(at: .corner(currentCorner), animated: true)
    }

    func close(to sourceFrame: CGRect?, completion: @escaping () -> Void) {
        isClosing = true
        isUserInteractionEnabled = false
        floatingView.isHidden = false
        UIView.animate(withDuration: 0.3, delay: 0, options: [.beginFromCurrentState, .curveEaseInOut], animations: {
            self.pullTab.alpha = 0
            if let sourceFrame = sourceFrame {
                self.floatingView.frame = sourceFrame
                self.clippingView.layer.cornerRadius = 0
            } else {
                self.floatingView.alpha = 0
            }
            self.floatingView.layoutIfNeeded()
        }, completion: { _ in completion() })
    }

    func tearDown() {
        containerController.onLayout = nil
        floatingView.layer.removeAllAnimations()
        pullTab.layer.removeAllAnimations()
        contentController.willMove(toParent: nil)
        contentController.view.removeFromSuperview()
        contentController.view.translatesAutoresizingMaskIntoConstraints = contentUsedAutoresizingMask
        NSLayoutConstraint.activate(rootSizeConstraints)
        contentController.removeFromParent()
        isHidden = true
        windowScene = nil
    }

    @objc private func pan(_ recognizer: UIPanGestureRecognizer) {
        guard !isClosing else { return }
        let translation = recognizer.translation(in: containerController.view)
        switch recognizer.state {
        case .began:
            isDragging = true
            dragStartPlacement = placement
            if let presentation = floatingView.layer.presentation() { floatingView.frame = presentation.frame }
            floatingView.layer.removeAllAnimations()
            pullTab.layer.removeAllAnimations()
            floatingView.isHidden = false
            floatingView.alpha = 1
            dragStartFrame = floatingView.frame
        case .changed:
            floatingView.frame.origin = CGPoint(x: dragStartFrame.minX + translation.x,
                                                 y: dragStartFrame.minY + translation.y)
            let frame = floatingView.frame
            if frame.minX < geometry.bounds.minX {
                configureTab(edge: .left, centerY: frame.midY)
                pullTab.alpha = min(1, (geometry.bounds.minX - frame.minX) / contentSize.width)
            } else if frame.maxX > geometry.bounds.maxX {
                configureTab(edge: .right, centerY: frame.midY)
                pullTab.alpha = min(1, (frame.maxX - geometry.bounds.maxX) / contentSize.width)
            } else {
                pullTab.alpha = 0
            }
        case .ended:
            isDragging = false
            let edge: PiPEdge?
            if case .tucked(let startingEdge, _) = dragStartPlacement { edge = startingEdge } else { edge = nil }
            let velocity = recognizer.velocity(in: containerController.view)
            let target = geometry.placement(afterDragging: floatingView.frame, translation: translation,
                                            velocity: velocity, startingCorner: currentCorner, startingEdge: edge)
            settle(at: target, animated: true, velocity: velocity)
        case .cancelled, .failed:
            isDragging = false
            settle(at: dragStartPlacement, animated: true)
        default: break
        }
    }

    @objc private func pinch(_ recognizer: UIPinchGestureRecognizer) {
        guard !isTucked, !isClosing, !isDragging else { return }
        if recognizer.state == .began { pinchStartSize = contentSize }
        let scale = min(1.65, max(0.85, pinchStartSize.width * recognizer.scale / requestedSize.width))
        contentSize = geometry.fittedSize(CGSize(width: requestedSize.width * scale,
                                                 height: requestedSize.height * scale))
        if recognizer.state == .ended || recognizer.state == .cancelled || recognizer.state == .failed {
            let finalScale = min(1.5, max(1, contentSize.width / requestedSize.width))
            contentSize = geometry.fittedSize(CGSize(width: requestedSize.width * finalScale,
                                                     height: requestedSize.height * finalScale))
            settle(at: .corner(currentCorner), animated: true)
        } else {
            settle(at: .corner(currentCorner), animated: false)
        }
    }
}

extension PiPWindow: UIPointerInteractionDelegate {}

private final class PiPContainerController: UIViewController {
    var onLayout: (() -> Void)?

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        onLayout?()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        onLayout?()
    }
}

private final class PiPPullTab: UIButton {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -6, dy: 0).contains(point)
    }
}
