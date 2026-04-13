import AppKit
import Core
import Foundation

struct FrontmostApplicationObservation {
    let displayName: String
    let bundleIdentifier: String?

    var asObservedApplication: ObservedApplication {
        ObservedApplication(
            displayName: displayName,
            bundleIdentifier: bundleIdentifier
        )
    }
}

enum ApplicationExclusionPolicy {
    static let builtInExcludedApplications: [ExcludedApplication] = [
        ExcludedApplication(displayName: "Terminal", bundleIdentifier: "com.apple.Terminal"),
        ExcludedApplication(displayName: "iTerm", bundleIdentifier: "com.googlecode.iterm2"),
        ExcludedApplication(displayName: "1Password", bundleIdentifier: "com.1password.1password"),
        ExcludedApplication(displayName: "Bitwarden", bundleIdentifier: "com.bitwarden.desktop"),
        ExcludedApplication(displayName: "LastPass", bundleIdentifier: "com.lastpass.LastPass"),
        ExcludedApplication(displayName: "Microsoft Remote Desktop", bundleIdentifier: "com.microsoft.rdc.macos"),
        ExcludedApplication(displayName: "Microsoft Remote Desktop", bundleIdentifier: "com.microsoft.rdc.mac"),
        ExcludedApplication(displayName: "Parallels Desktop", bundleIdentifier: "com.parallels.desktop.console"),
        ExcludedApplication(displayName: "VMware Fusion", bundleIdentifier: "com.vmware.fusion"),
        ExcludedApplication(displayName: "TeamViewer", bundleIdentifier: "com.teamviewer.TeamViewer"),
        ExcludedApplication(displayName: "AnyDesk", bundleIdentifier: "com.anydesk.Anydesk")
    ]

    private static var builtInExcludedBundleIdentifiers: Set<String> {
        Set(builtInExcludedApplications.map(\.bundleIdentifier))
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

    static func isBuiltInExcluded(bundleIdentifier: String) -> Bool {
        builtInExcludedBundleIdentifiers.contains(bundleIdentifier)
    }

    static func shouldExclude(
        _ application: FrontmostApplicationObservation?,
        manualBundleIdentifiers: Set<String>
    ) -> Bool {
        guard let bundleIdentifier = application?.bundleIdentifier else {
            return false
        }

        return builtInExcludedBundleIdentifiers.contains(bundleIdentifier)
            || manualBundleIdentifiers.contains(bundleIdentifier)
    }
}
