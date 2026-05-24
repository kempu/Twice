//
//  AboutSettingsPane.swift
//  Twice
//

import SwiftUI

struct AboutSettingsPane: View {
    @EnvironmentObject var appState: AppState

    private var updatesManager: UpdatesManager {
        appState.updatesManager
    }

    private var acknowledgementsURL: URL? {
        Bundle.main.url(forResource: "Acknowledgements", withExtension: "pdf")
    }

    private var sourceURL: URL {
        // swiftlint:disable:next force_unwrapping
        URL(string: "https://github.com/kempu/Twice")!
    }

    private var issuesURL: URL {
        sourceURL.appendingPathComponent("issues")
    }

    private var originalProjectURL: URL {
        // swiftlint:disable:next force_unwrapping
        URL(string: "https://github.com/jordanbaird/Ice")!
    }

    private var lastUpdateCheckString: String {
        if let date = updatesManager.lastUpdateCheckDate {
            date.formatted(date: .abbreviated, time: .standard)
        } else {
            "Never"
        }
    }

    private func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    var body: some View {
        VStack(spacing: 20) {
            mainForm
            bottomBar
        }
        .padding(30)
    }

    @ViewBuilder
    private var mainForm: some View {
        TwiceForm(padding: EdgeInsets(top: 5, leading: 30, bottom: 30, trailing: 30), spacing: 0) {
            appIconAndCopyrightSection
                .layoutPriority(1)

            Color.clear
                .frame(height: 20)

            updatesSection
                .layoutPriority(1)
        }
        .frame(minHeight: 0, maxHeight: .infinity)
        .background(.quinary, in: RoundedRectangle(cornerRadius: 20, style: .circular))
    }

    @ViewBuilder
    private var appIconAndCopyrightSection: some View {
        TwiceSection(options: .plain) {
            HStack(spacing: 10) {
                if let nsImage = NSImage(named: NSImage.applicationIconName) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 225)
                }

                VStack(alignment: .leading) {
                    Text("Twice")
                        .font(.system(size: 72, weight: .medium))
                        .foregroundStyle(.primary)

                    Text("Version \(Constants.versionString)")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)

                    Text(Constants.copyrightString)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.tertiary)

                    Text("Forked from Jordan Baird's Ice. Maintained as Twice because the original project appears abandoned and was failing on newer macOS releases.")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 390, alignment: .leading)
                        .padding(.top, 8)
                }
            }
        }
    }

    @ViewBuilder
    private var updatesSection: some View {
        TwiceSection(options: .hasDividers) {
            automaticallyCheckForUpdates
            automaticallyDownloadUpdates
            checkForUpdates
        }
        .frame(maxWidth: 600)
    }

    @ViewBuilder
    private var automaticallyCheckForUpdates: some View {
        Toggle(
            "Automatically check for updates",
            isOn: updatesManager.bindings.automaticallyChecksForUpdates
        )
    }

    @ViewBuilder
    private var automaticallyDownloadUpdates: some View {
        Toggle(
            "Automatically download updates",
            isOn: updatesManager.bindings.automaticallyDownloadsUpdates
        )
    }

    @ViewBuilder
    private var checkForUpdates: some View {
        HStack {
            Button(updatesManager.isCheckingForUpdates ? "Checking…" : "Check for Updates") {
                updatesManager.checkForUpdates()
            }
            .disabled(updatesManager.isCheckingForUpdates)
            Spacer()
            Text("Last checked: \(lastUpdateCheckString)")
                .font(.caption)
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        HStack {
            Button("Quit Twice") {
                NSApp.terminate(nil)
            }
            Spacer()
            Button("Acknowledgements") {
                if let acknowledgementsURL {
                    open(acknowledgementsURL)
                }
            }
            Button("Source Code") {
                open(sourceURL)
            }
            Button("Original Ice") {
                open(originalProjectURL)
            }
            Button("Report a Bug") {
                open(issuesURL)
            }
        }
        .padding(8)
        .buttonStyle(BottomBarButtonStyle())
        .background(.quinary, in: Capsule(style: .circular))
        .frame(height: 40)
    }
}

private struct BottomBarButtonStyle: ButtonStyle {
    @State private var isHovering = false

    private var borderShape: some InsettableShape {
        Capsule(style: .circular)
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background {
                borderShape
                    .fill(configuration.isPressed ? .tertiary : .quaternary)
                    .opacity(isHovering ? 1 : 0)
            }
            .contentShape([.focusEffect, .interaction], borderShape)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}
