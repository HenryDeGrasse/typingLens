import AppKit
import Foundation

struct FrontmostApplicationObservation {
    let displayName: String
    let bundleIdentifier: String?
}

enum ApplicationExclusionPolicy {
    private static let rules: [(bundleIdentifier: String, displayName: String)] = [
        ("com.apple.Terminal", "Terminal"),
        ("com.googlecode.iterm2", "iTerm"),
        ("com.1password.1password", "1Password"),
        ("com.bitwarden.desktop", "Bitwarden"),
        ("com.lastpass.LastPass", "LastPass"),
        ("com.microsoft.rdc.macos", "Microsoft Remote Desktop"),
        ("com.microsoft.rdc.mac", "Microsoft Remote Desktop"),
        ("com.parallels.desktop.console", "Parallels Desktop"),
        ("com.vmware.fusion", "VMware Fusion"),
        ("com.teamviewer.TeamViewer", "TeamViewer"),
        ("com.anydesk.Anydesk", "AnyDesk")
    ]

    static var excludedAppDisplayNames: [String] {
        Array(Set(rules.map(\.displayName))).sorted()
    }

    static var excludedBundleIdentifiers: [String] {
        Array(Set(rules.map(\.bundleIdentifier))).sorted()
    }

    static func currentFrontmostApplication() -> FrontmostApplicationObservation? {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        return FrontmostApplicationObservation(
            displayName: application.localizedName ?? application.bundleIdentifier ?? "Unknown App",
            bundleIdentifier: application.bundleIdentifier
        )
    }

    static func shouldExclude(_ application: FrontmostApplicationObservation?) -> Bool {
        guard let bundleIdentifier = application?.bundleIdentifier else {
            return false
        }

        return rules.contains(where: { $0.bundleIdentifier == bundleIdentifier })
    }
}
