import AppKit
import SwiftUI

struct AboutView: View {
    @ObservedObject private var updates = AppUpdates.shared
    @State private var notice: String?
    @State private var noticeTitle = "Licences"

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                        .resizable().frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(AppIdentity.name).font(.title2.weight(.semibold))
                        Text("© 2026 Theron Burger").foregroundStyle(.secondary)
                    }
                }.background(OverlayScrollbars())
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development")
                LabeledContent("Build", value: AppIdentity.build)
            }
            if updates.isAvailable {
                Section("Updates") {
                    Toggle("Check for updates automatically", isOn: $updates.automaticChecks)
                    Button("Check for Updates…") { updates.checkForUpdates() }.disabled(!updates.canCheck)
                }
            }
            Section("Source") {
                LabeledContent("Git revision", value: Bundle.main.object(forInfoDictionaryKey: "LiltGitRevision") as? String ?? "Unpackaged build")
                if let remote = Bundle.main.object(forInfoDictionaryKey: "LiltRepositoryURL") as? String, let url = URL(string: remote) {
                    Link("Git repository", destination: url)
                }
                if let path = Bundle.main.object(forInfoDictionaryKey: "LiltSourcePath") as? String {
                    Button("Show source in Finder") { NSWorkspace.shared.open(URL(fileURLWithPath: path)) }
                }
                Button("Lilt licence · MIT") { showNotice("Lilt · MIT", file: "Lilt", subdirectory: "Licenses") }
            }
            Section("Credits & licences") {
                credit("Kokoro", detail: "Speech · Apache 2.0", link: "https://github.com/hexgrad/kokoro", licence: "Kokoro-model")
                credit("Misaki", detail: "Pronunciation · Apache 2.0", link: "https://github.com/hexgrad/misaki")
                credit("Apple Vision", detail: "Text recognition · Built into macOS", link: "https://developer.apple.com/documentation/vision/recognizing-text-in-images")
                credit("KeyboardShortcuts", detail: "Shortcut recorder · MIT", link: "https://github.com/sindresorhus/KeyboardShortcuts", licence: "KeyboardShortcuts")
                credit("Sparkle", detail: "App updates · MIT", link: "https://sparkle-project.org", licence: "Sparkle")
                Link("Permission guide inspiration", destination: URL(string: "https://github.com/riko2chen/AskForPermission")!)
                Button("Open all third-party notices…") {
                    if let url = Bundle.main.url(forResource: "ThirdPartyNotices", withExtension: "txt") { NSWorkspace.shared.open(url) }
                }
            }
        }.formStyle(.grouped).settingsScrollEdges()
        .sheet(isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            VStack(alignment: .leading, spacing: 16) {
                Text(noticeTitle).font(.headline)
                ScrollView { Text(notice ?? "").font(.system(.body, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                HStack { Spacer(); Button("Done") { notice = nil }.keyboardShortcut(.cancelAction) }
            }.padding(24).frame(width: 640, height: 500)
        }
    }

    private func credit(_ title: String, detail: String, link: String, licence: String? = nil) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Link(title, destination: URL(string: link)!)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let licence { Button("Licence…") { showNotice(title, file: licence, subdirectory: "Licenses") } }
        }
    }

    private func showNotice(_ title: String, file: String, subdirectory: String?) {
        noticeTitle = title
        if let url = Bundle.main.url(forResource: file, withExtension: "txt", subdirectory: subdirectory),
           let text = try? String(contentsOf: url, encoding: .utf8) { notice = text }
        else { notice = "The licence file is missing from this build." }
    }
}
