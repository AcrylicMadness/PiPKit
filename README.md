# PiPKit

Interactive UIKit floating content windows for iOS 15 and later, with standalone
UIView and SwiftUI content, corner snapping, and edge tucking. No external dependencies.

## Standalone content

Keep a `PiPManager` alive for each scene, and pass the target `UIWindowScene` explicitly.
The content does not need an underlying source view. The actual view is hosted, so
buttons, gestures, and SwiftUI state remain live.

```swift
import PiPKit
import SwiftUI

let manager = PiPManager()
manager.presentPiP(content: PlayerControls(), in: windowScene,
                   size: CGSize(width: 240, height: 160))
// Or: manager.presentPiP(content: unattachedUIView, in: windowScene)

manager.togglePiP(content: PlayerControls(), in: windowScene) // present or close
manager.closePiP()       // animated close, including when tucked
manager.dismissPiP()    // immediate cleanup, e.g. on scene disconnection
```

`PlayerControls` represents your own SwiftUI `View`. A UIView must be unattached;
PiPKit takes ownership of its layout while presented and releases it on dismissal.
Presentation methods return whether the request was accepted. Each manager handles
one presentation at a time. An in-progress close must finish before presenting again.

`manager.isPresenting` and `manager.isTucked` report current state.
`manager.restorePiP()` brings tucked content back to a corner. All UI APIs use the main actor.
The scene's main window keeps key-window status, and touches outside PiP reach the app.
Bounds and safe-area changes are handled automatically for standalone content.

## Dragging and tucking

- Drag or flick to move between corners. Release velocity projects the target corner.
- Deliberately drag content outward past the left or right screen edge to tuck it.
  The content follows the drag interactively and settles into a small pull tab.
- A fast flick toward a different corner takes priority over tucking, even if the
  drag briefly crosses an edge. Velocity projection alone never tucks content.
- Tap the tab or pull it inward to restore. Moving a tucked tab vertically keeps it tucked.
- Pinch visible content to resize it, up to 1.5 times its initial size, within the safe area.

## Attached-view convenience

The original API remains available. It displays a copy of an attached source view
and covers that source with a placeholder until the PiP closes. Adopt
`PiPSceneDelegate` to make the UIView convenience methods find your scene's manager:

```swift
import UIKit
import PiPKit

final class SceneDelegate: UIResponder, PiPSceneDelegate {
    var window: UIWindow?
    let pipManager = PiPManager()

    // Create the scene's main window using your app's normal setup.

    func sceneDidDisconnect(_ scene: UIScene) {
        pipManager.dismissPiP()
        window = nil
    }
}
```

```swift
let insets = view.safeAreaInsets.extendedBy(16)
imageView.moveToPiP(withBounds: view.bounds, andInsets: insets)
imageView.changePiPBounds(newBounds: view.bounds, andInsets: insets)
imageView.closePiP()
```

`imageView.isInPiP` reports whether that view belongs to the presentation. The
attached-view path uses NSCoding to copy the view; standalone presentation does not
copy or archive its content. The scene-delegate protocol is optional when using
`PiPManager` directly.

## Validation

Run the placement regression tests on an installed iOS Simulator:

```sh
xcodebuild -scheme PiPKit -destination 'platform=iOS Simulator,name=iPhone 18 Pro' test
```

Tests cover all corner-to-corner flicks, intentional tucking on both edges,
accidental overshoot, pull-tab restoration, safe areas, and fitting content to small bounds.
