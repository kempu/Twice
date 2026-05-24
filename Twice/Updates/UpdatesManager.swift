//
//  UpdatesManager.swift
//  Twice
//

import Sparkle
import SwiftUI

/// Manager for app updates.
@MainActor
final class UpdatesManager: NSObject, ObservableObject {
    /// A Boolean value that indicates whether the user can check for updates.
    @Published var canCheckForUpdates = false

    /// The date of the last update check.
    @Published var lastUpdateCheckDate: Date?

    /// A Boolean value that indicates whether an update check is running.
    @Published var isCheckingForUpdates = false

    /// The shared app state.
    private(set) weak var appState: AppState?

    /// A Boolean value that indicates whether setup has already run.
    private var isSetup = false

    /// The latest GitHub release endpoint.
    private let latestReleaseURL = URL(string: "https://api.github.com/repos/kempu/Twice/releases/latest")!

    /// The underlying updater controller.
    private(set) lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: self,
        userDriverDelegate: self
    )

    /// The underlying updater.
    var updater: SPUUpdater {
        updaterController.updater
    }

    /// A Boolean value that indicates whether to automatically check for updates.
    var automaticallyChecksForUpdates: Bool {
        get {
            updater.automaticallyChecksForUpdates
        }
        set {
            objectWillChange.send()
            updater.automaticallyChecksForUpdates = newValue
        }
    }

    /// A Boolean value that indicates whether to automatically download updates.
    var automaticallyDownloadsUpdates: Bool {
        get {
            updater.automaticallyDownloadsUpdates
        }
        set {
            objectWillChange.send()
            updater.automaticallyDownloadsUpdates = newValue
        }
    }

    /// Creates an updates manager with the given app state.
    init(appState: AppState) {
        self.appState = appState
        super.init()
    }

    /// Sets up the manager.
    func performSetup() {
        guard !isSetup else {
            return
        }
        isSetup = true

        _ = updaterController
        syncUpdaterState()
        configureCancellables()
    }

    /// Syncs published state with the underlying updater.
    private func syncUpdaterState() {
        canCheckForUpdates = updater.canCheckForUpdates
        lastUpdateCheckDate = updater.lastUpdateCheckDate
    }

    /// Configures the internal observers for the manager.
    private func configureCancellables() {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
        updater.publisher(for: \.lastUpdateCheckDate)
            .assign(to: &$lastUpdateCheckDate)
    }

    /// Checks for app updates.
    @objc func checkForUpdates() {
        guard !isCheckingForUpdates else {
            return
        }

        guard let appState else {
            return
        }

        // Activate the app in case an alert needs to be displayed.
        appState.activate(withPolicy: .regular)
        appState.navigationState.settingsNavigationIdentifier = .about
        appState.openSettingsWindow()

        Task {
            await checkGitHubForUpdates()
        }
    }

    /// Shows an alert owned by the app.
    private func showAlert(message: String, informativeText: String = "") {
        appState?.activate(withPolicy: .regular)

        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = informativeText
        alert.runModal()
    }

    /// Checks GitHub Releases for the latest available version.
    private func checkGitHubForUpdates() async {
        isCheckingForUpdates = true
        defer {
            isCheckingForUpdates = false
        }

        do {
            let release = try await fetchLatestRelease()
            lastUpdateCheckDate = .now

            if isVersion(release.version, newerThan: Constants.versionString) {
                showUpdateAvailableAlert(for: release)
            } else {
                showAlert(message: "Twice is up to date.")
            }
        } catch {
            showAlert(
                message: "Unable to check for updates.",
                informativeText: error.localizedDescription
            )
        }
    }

    /// Fetches the latest GitHub release.
    private func fetchLatestRelease() async throws -> GitHubRelease {
        let (data, response) = try await URLSession.shared.data(from: latestReleaseURL)

        guard
            let httpResponse = response as? HTTPURLResponse,
            200..<300 ~= httpResponse.statusCode
        else {
            throw UpdateCheckError.invalidResponse
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(GitHubRelease.self, from: data)
    }

    /// Shows an update alert for the given release.
    private func showUpdateAvailableAlert(for release: GitHubRelease) {
        let alert = NSAlert()
        alert.messageText = "Version \(release.version) is available."
        alert.informativeText = "You are running version \(Constants.versionString)."
        alert.addButton(withTitle: "Open Release")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(release.htmlUrl)
        }
    }

    /// Returns whether the first version is newer than the second.
    private func isVersion(_ version: String, newerThan currentVersion: String) -> Bool {
        normalizedVersion(version)
            .compare(normalizedVersion(currentVersion), options: [.caseInsensitive, .numeric]) == .orderedDescending
    }

    /// Normalizes version tags for comparison.
    private func normalizedVersion(_ version: String) -> String {
        version.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }
}

// MARK: UpdatesManager: SPUUpdaterDelegate
extension UpdatesManager: @preconcurrency SPUUpdaterDelegate {
    func updaterShouldPromptForPermissionToCheck(forUpdates updater: SPUUpdater) -> Bool {
        false
    }

    func updater(_ updater: SPUUpdater, willScheduleUpdateCheckAfterDelay delay: TimeInterval) {
        guard let appState else {
            return
        }
        appState.userNotificationManager.requestAuthorization()
    }
}

// MARK: UpdatesManager: SPUStandardUserDriverDelegate
extension UpdatesManager: @preconcurrency SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        if NSApp.isActive {
            return immediateFocus
        } else {
            return false
        }
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        guard let appState else {
            return
        }
        if !state.userInitiated {
            appState.userNotificationManager.addRequest(
                with: .updateCheck,
                title: "A new update is available",
                body: "Version \(update.displayVersionString) is now available"
            )
        }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        guard let appState else {
            return
        }
        appState.userNotificationManager.removeDeliveredNotifications(with: [.updateCheck])
    }
}

// MARK: UpdatesManager: BindingExposable
extension UpdatesManager: BindingExposable { }

// MARK: - GitHubRelease
private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlUrl: URL

    var version: String {
        tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    }
}

// MARK: - UpdateCheckError
private enum UpdateCheckError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "GitHub returned an invalid response."
        }
    }
}
