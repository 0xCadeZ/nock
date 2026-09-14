import AppKit
import Foundation

enum RunningApps {
    /// Process id of a running, non-terminating instance of the app, or nil.
    static func processID(for bundleID: String) -> pid_t? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first(where: { !$0.isTerminated })?
            .processIdentifier
    }

    /// Brings an already running app to the front. Never launches it.
    static func activate(_ bundleID: String) {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.activate()
    }
}
