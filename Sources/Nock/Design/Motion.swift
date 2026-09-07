import SwiftUI

enum Motion {
    /// Shape morph — slight overshoot, like iOS Dynamic Island.
    static let expand = Animation.spring(response: 0.44, dampingFraction: 0.74)
    static let collapse = Animation.spring(response: 0.30, dampingFraction: 0.90)
    static let snap = Animation.spring(response: 0.22, dampingFraction: 0.86)
    /// Player chrome fades in after the silhouette has started opening.
    static let contentIn = Animation.easeOut(duration: 0.20).delay(0.07)
    static let contentOut = Animation.easeIn(duration: 0.10)
    static let icon = Animation.easeOut(duration: 0.12)
    static let sneakPeekDuration: TimeInterval = 2.2
    static let hoverExitDelay: TimeInterval = 0.22
}
