import SwiftUI
import LiltCore
import KeyboardShortcuts

extension Notification.Name { static let showLiltAbout = Self("showLiltAbout") }

struct LibraryView: View {
    @ObservedObject var model: AppModel
    @State private var section = "History"
    @State private var search = ""
    @State private var showingPaste = false
    @State private var draft = ""

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "waveform").font(.system(size: 32)).foregroundStyle(Color.accentColor)
                    Text(AppIdentity.name).font(.largeTitle.weight(.semibold))
                }.padding(.horizontal, 16).padding(.top, 24)
                List(selection: $section) {
                    Label("History", systemImage: "clock.arrow.circlepath").tag("History")
                    Label("Voice & reading", systemImage: "slider.horizontal.3").tag("Settings")
                    Label("Settings", systemImage: "gearshape").tag("App")
                    Label("About", systemImage: "info.circle").tag("About")
                }.listStyle(.sidebar)
            }.navigationSplitViewColumnWidth(min: 180, ideal: 205, max: 250)
        } detail: {
            Group {
                if section == "Settings" { settings }
                else if section == "App" { appSettings }
                else if section == "About" { AboutView() }
                else { history }
            }
            .navigationTitle(section == "Settings" ? "Voice & reading" : section == "App" ? "Settings" : section == "About" ? "About" : "Your readings")
            .toolbar {
                ToolbarItemGroup {
                    Button { model.readClipboard() } label: { Label("Read clipboard", systemImage: "play.rectangle.on.rectangle") }
                        .help("Read clipboard immediately")
                    Button { draft = ""; showingPaste = true } label: { Label("Paste text", systemImage: "doc.on.clipboard") }
                    Button { model.capture?() } label: { Label("Capture", systemImage: "viewfinder") }
                        .disabled(model.isCapturing)
                }
            }
        }

        .frame(minWidth: 760, minHeight: 540)
        .onReceive(NotificationCenter.default.publisher(for: .showLiltAbout)) { _ in section = "About" }
        .sheet(isPresented: $showingPaste) {
            VStack(alignment: .leading, spacing: 18) {
                Text("What would you like to read?").font(.title2.weight(.semibold))
                Text("Paste a passage, a message, or something worth slowing down for.")
                    .foregroundStyle(.secondary)
                TextEditor(text: $draft).font(.body).padding(8)
                    .background(.background, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
                HStack {
                    Button("From clipboard") { draft = NSPasteboard.general.string(forType: .string) ?? "" }
                    Spacer()
                    Button("Cancel") { showingPaste = false }.keyboardShortcut(.cancelAction)
                    Button("Read aloud") { showingPaste = false; model.read(draft) }
                        .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }.padding(28).frame(width: 580, height: 400)
        }
        .alert("\(AppIdentity.name) needs a moment", isPresented: Binding(get: { model.error != nil && (model.captureImage == nil || model.needsScreenPermission) }, set: { if !$0 { model.error = nil } })) {
            if model.needsScreenPermission {
                Button("Open System Settings") {
                    model.openScreenPermissions?()
                    model.error = nil
                }
            }
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Text("\(model.history.count) readings").font(.caption).foregroundStyle(.tertiary)
            }.padding(24)
            if model.history.isEmpty {
                ContentUnavailableView {
                    Label("Give your eyes a breather", systemImage: "text.viewfinder")
                } description: {
                    Text("Capture text anywhere on screen.\nListen, follow along, and find it here later.")
                } actions: {
                    Button("Try Lilt") { model.read(AppModel.sample, source: "Welcome to Lilt") }
                        .buttonStyle(.borderedProminent)
                    Button("Capture text") { model.capture?() }
                }
            } else {
                List {
                    ForEach(model.history.filter { search.isEmpty || $0.text.localizedCaseInsensitiveContains(search) || $0.title.localizedCaseInsensitiveContains(search) }) { reading in
                        HStack(spacing: 14) {
                            Image(systemName: reading.source == "Screen capture" ? "viewfinder" : "text.alignleft")
                                .font(.title2).foregroundStyle(Color.accentColor)
                                .frame(width: 44, height: 48)
                                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 7) {
                                Text(reading.title).font(.headline).lineLimit(1)
                                Text("\(reading.wordCount) words · \(reading.source) · \(reading.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button { model.open(reading) } label: { Image(systemName: "play.fill") }
                                .buttonStyle(.borderless).help("Read again").accessibilityLabel("Read \(reading.title)")
                            Button(role: .destructive) { model.delete(reading) } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless).help("Delete reading").accessibilityLabel("Delete \(reading.title)")
                        }
                        .padding(.vertical, 10).padding(.trailing, 24).contentShape(Rectangle())
                        .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] - 24 }
                        .background(OverlayScrollbars())
                        .onTapGesture(count: 2) { model.open(reading) }
                        .contextMenu {
                            Button("Read") { model.open(reading) }
                            Button("Export text…") { model.export(reading, audio: false) }
                            Button("Export audio…") { model.export(reading, audio: true) }.disabled(!model.store.hasAudio(for: reading))
                            Button("Copy text") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(reading.text, forType: .string)
                            }
                            Divider()
                            Button("Delete", role: .destructive) { model.delete(reading) }
                        }
                    }
                }.listStyle(.inset).settingsScrollEdges().searchable(text: $search, prompt: "Search your readings")
            }
        }
    }

    private var settings: some View {
        Form {
            Section("Reading") {
                HStack {
                    Text("Playback speed").frame(width: 130, alignment: .leading)
                    Slider(value: Binding(get: { model.speed }, set: { model.speed = ($0 * 20).rounded() / 20 }), in: 0.75...2)
                        .accessibilityLabel("Playback speed")
                    Text("\(model.speed.formatted())×").monospacedDigit().frame(width: 46)
                }.background(OverlayScrollbars())
                HStack {
                    Text("Text size").frame(width: 130, alignment: .leading)
                    Slider(value: Binding(get: { model.fontSize }, set: { model.fontSize = $0.rounded() }), in: 17...38)
                        .accessibilityLabel("Text size")
                    Text("\(Int(model.fontSize))").monospacedDigit().frame(width: 46)
                }
                Text("The words find their rhythm.").font(.system(size: model.fontSize))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            Section("Voice") {
                Text("Kokoro").font(.caption).foregroundStyle(.secondary)
                ForEach(["American English", "British English"], id: \.self) { language in
                    Text(language).font(.headline)
                    ForEach(Voice.all.filter { $0.language == language }) { voice in
                        HStack {
                            Button { model.voice = voice.id } label: {
                                HStack {
                                    Image(systemName: model.voice == voice.id ? "checkmark.circle.fill" : "circle")
                                    Text(voice.name)
                                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                            }.buttonStyle(.plain).accessibilityLabel("Use \(voice.name)")
                            Button { model.previewVoice(voice) } label: {
                                Image(systemName: model.previewingVoice == voice.id ? "stop.fill" : "play.fill")
                            }.buttonStyle(.borderless).accessibilityLabel("Preview \(voice.name)")
                        }
                    }
                }
            }
        }.formStyle(.grouped).settingsScrollEdges()
    }

    private var appSettings: some View {
        Form {
            Section("Visibility") {
                Toggle("Show in menu bar", isOn: $model.showInMenuBar)
                    .background(OverlayScrollbars())
                Toggle("Show in Dock & app switcher (⌘Tab)", isOn: $model.showInDock)
            }
            Section("Capture") {
                KeyboardShortcuts.Recorder("Capture shortcut", name: .captureText, onChange: { _ in checkShortcuts() })
                    .shortcutValidation { GlobalShortcut.validate($0, for: .captureText) }
                KeyboardShortcuts.Recorder("Read clipboard shortcut", name: .readClipboard, onChange: { _ in checkShortcuts() })
                    .shortcutValidation { GlobalShortcut.validate($0, for: .readClipboard) }
                Button("Screen Recording permission…") {
                    model.openScreenPermissions?()
                }
            }
            AISettingsView(model: model)
            Section("History") {
                Picker("Delete readings after", selection: $model.retentionDays) {
                    Text("1 day").tag(1)
                    Text("1 week").tag(7)
                    Text("1 month").tag(30)
                    Text("Never").tag(0)
                }
                Button("Show local files") { NSWorkspace.shared.open(model.store.directory) }
            }
        }.formStyle(.grouped).settingsScrollEdges()
    }

    private func checkShortcuts() {
        // Registration resumes when the recorder releases focus.
        DispatchQueue.main.async {
            if let error = GlobalShortcut.registrationError() { model.error = error }
        }
    }
}
