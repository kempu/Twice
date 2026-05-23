//
//  MenuBarItem.swift
//  Twice
//

import Cocoa
import AXSwift

// MARK: - MenuBarItem

/// A representation of an item in the menu bar.
struct MenuBarItem {
    /// The item's window.
    let window: WindowInfo

    /// The menu bar item info associated with this item.
    let info: MenuBarItemInfo

    /// The process identifier of the application that created the item.
    let sourcePID: pid_t?

    /// The identifier of the item's window.
    var windowID: CGWindowID {
        window.windowID
    }

    /// The frame of the item's window.
    var frame: CGRect {
        window.frame
    }

    /// The title of the item's window.
    var title: String? {
        window.title
    }

    /// A Boolean value that indicates whether the item is on screen.
    var isOnScreen: Bool {
        window.isOnScreen
    }

    /// A Boolean value that indicates whether the item can be moved.
    var isMovable: Bool {
        let immovableItems = Set(MenuBarItemInfo.immovableItems)
        return !immovableItems.contains(info)
    }

    /// A Boolean value that indicates whether the item can be hidden.
    var canBeHidden: Bool {
        let nonHideableItems = Set(MenuBarItemInfo.nonHideableItems)
        return !nonHideableItems.contains(info)
    }

    /// The process identifier of the application that owns the item.
    var ownerPID: pid_t {
        window.ownerPID
    }

    /// The name of the application that owns the item.
    ///
    /// This may have a value when ``owningApplication`` does not have
    /// a localized name.
    var ownerName: String? {
        window.ownerName
    }

    /// The application that owns the item.
    var owningApplication: NSRunningApplication? {
        window.owningApplication
    }

    /// The application that created the item.
    var sourceApplication: NSRunningApplication? {
        guard let sourcePID else {
            return nil
        }
        return NSRunningApplication(processIdentifier: sourcePID)
    }

    /// The application best suited for user-facing names and icons.
    private var displayApplication: NSRunningApplication? {
        if #available(macOS 26.0, *), let sourceApplication {
            return sourceApplication
        }
        return owningApplication
    }

    /// A Boolean value that indicates whether this is a system-created clone.
    var isSystemClone: Bool {
        title == "System Status Item Clone"
    }

    /// A Boolean value that indicates whether this item is a macOS 26 Control Center
    /// proxy that could not be matched back to a source app.
    var isUnresolvedControlCenterProxy: Bool {
        guard #available(macOS 26.0, *) else {
            return false
        }
        return sourcePID == nil &&
        info.namespace == .controlCenter &&
        title?.wholeMatch(of: /Item-\d+/) != nil
    }

    /// A Boolean value that indicates whether Twice should expose this item to users.
    var isManageableCandidate: Bool {
        !isSystemClone && !isUnresolvedControlCenterProxy
    }

    /// A name associated with the item that is suited for display to
    /// the user.
    var displayName: String {
        if info == .twiceIcon {
            return "Twice"
        }

        var fallback: String { "Unknown" }
        guard let application = displayApplication else {
            return ownerName ?? title ?? fallback
        }
        var bestName: String {
            application.localizedName ??
            ownerName ??
            application.bundleIdentifier ??
            fallback
        }
        guard let title else {
            return bestName
        }
        // by default, use the application name, but handle a few special cases
        return switch MenuBarItemInfo.Namespace(application.bundleIdentifier) {
        case .controlCenter:
            switch title {
            case "AccessibilityShortcuts": "Accessibility Shortcuts"
            case "BentoBox", "BentoBox-0": bestName // Control Center
            case "FocusModes": "Focus"
            case "KeyboardBrightness": "Keyboard Brightness"
            case "MusicRecognition": "Music Recognition"
            case "NowPlaying": "Now Playing"
            case "ScreenMirroring": "Screen Mirroring"
            case "StageManager": "Stage Manager"
            case "UserSwitcher": "Fast User Switching"
            case "WiFi": "Wi-Fi"
            default: title
            }
        case .systemUIServer:
            switch title {
            case "TimeMachine.TMMenuExtraHost"/*Sonoma*/, "TimeMachineMenuExtra.TMMenuExtraHost"/*Sequoia*/: "Time Machine"
            default: title
            }
        case MenuBarItemInfo.Namespace("com.apple.Passwords.MenuBarExtra"): "Passwords"
        default:
            bestName
        }
    }

    /// A Boolean value that indicates whether the item is currently
    /// in the menu bar.
    var isCurrentlyInMenuBar: Bool {
        let list = Set(Bridging.getWindowList(option: .menuBarItems))
        return list.contains(windowID)
    }

    /// A string to use for logging purposes.
    var logString: String {
        String(describing: info)
    }

    /// Creates a menu bar item from the given window.
    ///
    /// This initializer does not perform any checks on the window to ensure that
    /// it is a valid menu bar item window. Only call this initializer if you are
    /// certain that the window is valid.
    private init(uncheckedItemWindow itemWindow: WindowInfo) {
        self.window = itemWindow
        if #available(macOS 26.0, *) {
            self.sourcePID = MenuBarItemSourceCache.shared.sourcePID(for: itemWindow)
        } else {
            self.sourcePID = itemWindow.ownerPID
        }
        self.info = MenuBarItemInfo(uncheckedItemWindow: itemWindow, sourcePID: sourcePID)
    }

    /// Creates a menu bar item from the given window and info.
    ///
    /// This initializer does not perform any checks on the window to ensure that
    /// it is a valid menu bar item window. Only call this initializer if you are
    /// certain that the window is valid.
    private init(uncheckedItemWindow itemWindow: WindowInfo, info: MenuBarItemInfo, sourcePID: pid_t?) {
        self.window = itemWindow
        self.info = info
        self.sourcePID = sourcePID
    }

    /// Returns this item with the given info.
    func replacingInfo(_ info: MenuBarItemInfo) -> MenuBarItem {
        MenuBarItem(uncheckedItemWindow: window, info: info, sourcePID: sourcePID)
    }

    /// Creates a menu bar item.
    ///
    /// The parameters passed into this initializer are verified during the menu
    /// bar item's creation. If `itemWindow` does not represent a menu bar item,
    /// the initializer will fail.
    ///
    /// - Parameter itemWindow: A window that contains information about the item.
    init?(itemWindow: WindowInfo) {
        guard itemWindow.isMenuBarItem else {
            return nil
        }
        self.init(uncheckedItemWindow: itemWindow)
    }

    /// Creates a menu bar item with the given window identifier.
    ///
    /// The parameters passed into this initializer are verified during the menu
    /// bar item's creation. If `windowID` does not represent a menu bar item,
    /// the initializer will fail.
    ///
    /// - Parameter windowID: An identifier for a window that contains information
    ///   about the item.
    init?(windowID: CGWindowID) {
        guard let window = WindowInfo(windowID: windowID) else {
            return nil
        }
        self.init(itemWindow: window)
    }
}

// MARK: MenuBarItem Getters
extension MenuBarItem {
    /// Returns an array of the current menu bar items in the menu bar on the given display.
    ///
    /// - Parameters:
    ///   - display: The display to retrieve the menu bar items on. Pass `nil` to return the
    ///     menu bar items across all displays.
    ///   - onScreenOnly: A Boolean value that indicates whether only the menu bar items that
    ///     are on screen should be returned.
    ///   - activeSpaceOnly: A Boolean value that indicates whether only the menu bar items
    ///     that are on the active space should be returned.
    static func getMenuBarItems(on display: CGDirectDisplayID? = nil, onScreenOnly: Bool, activeSpaceOnly: Bool) -> [MenuBarItem] {
        var option: Bridging.WindowListOption = [.menuBarItems]

        var titlePredicate: (MenuBarItem) -> Bool = { _ in true }
        var boundsPredicate: (CGWindowID) -> Bool = { _ in true }

        if onScreenOnly {
            option.insert(.onScreen)
        }
        if activeSpaceOnly {
            option.insert(.activeSpace)
            titlePredicate = { $0.title != "" }
        }
        if let display {
            let displayBounds = CGDisplayBounds(display)
            boundsPredicate = { windowID in
                guard let windowFrame = Bridging.getWindowFrame(for: windowID) else {
                    return false
                }
                return displayBounds.intersects(windowFrame)
            }
        }

        return Bridging.getWindowList(option: option).lazy
            .filter(boundsPredicate)
            .compactMap { windowID in
                guard let window = WindowInfo(windowID: windowID) else {
                    return nil
                }
                return MenuBarItem(uncheckedItemWindow: window)
            }
            .filter(titlePredicate)
            .sortedByOrderInMenuBar()
    }
}

// MARK: MenuBarItem: Equatable
extension MenuBarItem: Equatable {
    static func == (lhs: MenuBarItem, rhs: MenuBarItem) -> Bool {
        lhs.window == rhs.window
    }
}

// MARK: MenuBarItem: Hashable
extension MenuBarItem: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(window)
    }
}

// MARK: - MenuBarItem Source Cache

@available(macOS 26.0, *)
private final class MenuBarItemSourceCache {
    /// A cached running application and its extras menu bar.
    private final class CachedApplication {
        private let runningApplication: NSRunningApplication
        private var extrasMenuBar: UIElement?

        var processIdentifier: pid_t {
            runningApplication.processIdentifier
        }

        init(_ runningApplication: NSRunningApplication) {
            self.runningApplication = runningApplication
        }

        private var isValidForAccessibility: Bool {
            runningApplication.isFinishedLaunching &&
            !runningApplication.isTerminated &&
            runningApplication.activationPolicy != .prohibited &&
            Bridging.responsivity(for: processIdentifier) != .unresponsive
        }

        func getExtrasMenuBar() -> UIElement? {
            if let extrasMenuBar {
                return extrasMenuBar
            }

            guard
                isValidForAccessibility,
                let application = Application(runningApplication),
                let bar: UIElement = try? application.attribute(.extrasMenuBar)
            else {
                return nil
            }

            extrasMenuBar = bar
            return bar
        }
    }

    /// Shared cache instance.
    static let shared = MenuBarItemSourceCache()

    private var runningApplicationPIDs = Set<pid_t>()
    private var applications = [CachedApplication]()
    private var sourcePIDs = [CGWindowID: pid_t]()

    private init() { }

    /// Returns the source process identifier for the given window.
    func sourcePID(for window: WindowInfo) -> pid_t? {
        if let sourcePID = sourcePIDs[window.windowID] {
            return sourcePID
        }

        updateRunningApplicationsIfNeeded()

        guard
            AXIsProcessTrusted(),
            let windowFrame = stableFrame(for: window)
        else {
            return nil
        }

        for application in applications {
            guard let extrasMenuBar = application.getExtrasMenuBar() else {
                continue
            }

            let children: [UIElement] = (try? extrasMenuBar.arrayAttribute(.children)) ?? []
            for child in children {
                guard
                    (try? child.attribute(.enabled) as Bool?) == true,
                    let childFrame: CGRect = try? child.attribute(.frame),
                    childFrame.center.distance(to: windowFrame.center) <= 2
                else {
                    continue
                }

                sourcePIDs[window.windowID] = application.processIdentifier
                return application.processIdentifier
            }
        }

        return nil
    }

    private func updateRunningApplicationsIfNeeded() {
        let runningApplications = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy != .prohibited
        }
        let currentPIDs = Set(runningApplications.map(\.processIdentifier))

        guard currentPIDs != runningApplicationPIDs else {
            return
        }

        let applicationByPID = applications.reduce(into: [pid_t: CachedApplication]()) { result, application in
            result[application.processIdentifier] = application
        }

        runningApplicationPIDs = currentPIDs
        applications = runningApplications.map { runningApplication in
            applicationByPID[runningApplication.processIdentifier] ?? CachedApplication(runningApplication)
        }
        sourcePIDs = sourcePIDs.filter { currentPIDs.contains($0.value) }
    }

    private func stableFrame(for window: WindowInfo) -> CGRect? {
        var frame = window.frame

        for attempt in 1...5 {
            guard let currentFrame = Bridging.getWindowFrame(for: window.windowID) else {
                return nil
            }
            if currentFrame == frame {
                return currentFrame
            }
            frame = currentFrame
            Thread.sleep(forTimeInterval: TimeInterval(attempt) / 100)
        }

        return frame
    }
}

// MARK: - Geometry Helpers

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }
}

// MARK: MenuBarItemInfo Unchecked Item Window Initializer
private extension MenuBarItemInfo {
    /// Creates a simplified item from the given window.
    ///
    /// This initializer does not perform any checks on the window to ensure that
    /// it is a valid menu bar item window. Only call this initializer if you are
    /// certain that the window is valid.
    init(uncheckedItemWindow itemWindow: WindowInfo, sourcePID: pid_t?) {
        let title = itemWindow.title ?? ""
        if ControlItem.Identifier(rawValue: title) != nil {
            if #available(macOS 26.0, *) {
                self = MenuBarItemInfo(namespace: .controlCenter, title: title)
            } else {
                self = MenuBarItemInfo(namespace: .twice, title: title)
            }
            return
        }

        if
            #available(macOS 26.0, *),
            let sourcePID,
            let sourceApplication = NSRunningApplication(processIdentifier: sourcePID)
        {
            self.namespace = Namespace(sourceApplication.bundleIdentifier ?? sourceApplication.localizedName)
        } else if let bundleIdentifier = itemWindow.owningApplication?.bundleIdentifier {
            self.namespace = Namespace(bundleIdentifier)
        } else {
            self.namespace = .null
        }
        self.title = title
    }
}
