import SwiftUI
import UniformTypeIdentifiers

private enum Tab: CaseIterable {
    case learn
    case practice
    case profile

    var label: String {
        switch self {
        case .learn: return "Learn"
        case .practice: return "Practice"
        case .profile: return "Profile"
        }
    }
}

/// The root: tabs underneath, the lesson (when one is running) over everything.
struct InfralingoRoot: View {
    @StateObject private var viewModel: InfralingoViewModel
    @State private var tab: Tab = {
        // UI-check hook: `-autostartTab practice` or `-autostartTab profile`.
        switch UserDefaults.standard.string(forKey: "autostartTab") {
        case "practice": return .practice
        case "profile": return .profile
        default: return .learn
        }
    }()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let store: ProgressStore
        do {
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            store = try ProgressStore(path: directory.appendingPathComponent("infralingo.db").path)
        } catch {
            // The database is the only place progress lives; if it cannot open, say so on screen.
            store = try! ProgressStore(path: nil)
        }
        _viewModel = StateObject(wrappedValue: InfralingoViewModel(content: ContentRepository(), store: store))
    }

    var body: some View {
        InfralingoTheme {
            ZStack {
                // Lives below the lesson so coming back lands on the tab the lesson was started from.
                MainTabs(viewModel: viewModel, tab: $tab)
                    .opacity(viewModel.lesson == nil ? 1 : 0)
                if let shown = viewModel.lesson {
                    LessonScreen(
                        ui: shown,
                        onSelect: viewModel.select,
                        onHint: viewModel.hint,
                        onCheck: viewModel.check,
                        onNext: viewModel.next,
                        onClose: viewModel.close,
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity),
                    ))
                }
            }
            .background(backgroundColor)
            .animation(.easeInOut(duration: 0.22), value: viewModel.lesson == nil)
            .overlay(alignment: .bottom) {
                Toast(message: viewModel.notice) {
                    viewModel.consumeNotice()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    viewModel.refresh()
                }
            }
        }
    }

    @Environment(\.palette) private var themePalette

    private var backgroundColor: Color? {
        viewModel.lesson == nil ? themePalette.background : nil
    }
}

private extension View {
    @ViewBuilder
    func background(_ color: Color?) -> some View {
        if let color { self.background(color) } else { self }
    }
}

private struct MainTabs: View {
    @ObservedObject var viewModel: InfralingoViewModel
    @Binding var tab: Tab

    var body: some View {
        let app = viewModel.app
        VStack(spacing: 0) {
            if app.loading {
                Notice(mood: .happy, text: "Loading your path…")
            } else if let error = app.error {
                Notice(mood: .oops, text: error)
            } else {
                switch tab {
                case .learn:
                    LearnScreen(stats: app.stats, units: app.units, onStart: viewModel.start)
                case .practice:
                    PracticeScreen(practice: app.practice, onStart: viewModel.start)
                case .profile:
                    ProfileRoute(app: app, viewModel: viewModel)
                }
                TabBar(selected: tab, onTab: { tab = $0 })
            }
        }
    }
}

private struct Notice: View {
    var mood: Mood
    var text: String

    var body: some View {
        VStack(spacing: 16) {
            Mascot(mood: mood)
                .frame(width: 120, height: 120)
            Text(text)
                .font(Type.heading)
                .foregroundColor(palette.textSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
    }

    @Environment(\.palette) private var palette
}

/// Android's Toast, ported: a short message near the bottom that goes away on its own.
private struct Toast: View {
    let message: String?
    let onDismiss: () -> Void

    @State private var shown: String?

    var body: some View {
        ZStack {
            if let shown {
                Text(shown)
                    .font(Type.small)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 10, style: .circular))
                    .padding(.bottom, 88)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: shown)
        .onChange(of: message) { message in
            guard let message else { return }
            shown = message
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation { shown = nil }
                onDismiss()
            }
        }
    }
}

private struct TabBar: View {
    let selected: Tab
    let onTab: (Tab) -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(palette.border)
                .frame(height: 2)
            HStack(spacing: 0) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    let active = tab == selected
                    Button {
                        onTab(tab)
                    } label: {
                        VStack(spacing: 4) {
                            ZStack {
                                if active {
                                    RoundedRectangle(cornerRadius: 12, style: .circular)
                                        .fill(palette.selectedTint)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .circular)
                                                .strokeBorder(palette.selectedBorder, lineWidth: 2),
                                        )
                                        .frame(width: 56, height: 44)
                                }
                                switch tab {
                                case .learn:
                                    HomeIcon(tint: palette.orange.face).frame(width: 30, height: 30)
                                case .practice:
                                    DumbbellIcon(tint: palette.blue.face).frame(width: 32, height: 32)
                                case .profile:
                                    PersonIcon(tint: palette.unit(1).face).frame(width: 30, height: 30)
                                }
                            }
                            .frame(height: 44)
                            Text(tab.label)
                                .textCase(.uppercase)
                                .font(Type.eyebrow)
                                .kerning(Type.labelKerning)
                                .foregroundColor(active ? palette.selectedInk : palette.textSoft)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
            .padding(.bottom, 2)
        }
        .background(palette.background)
    }
}

private struct ProfileRoute: View {
    let app: AppUi
    @ObservedObject var viewModel: InfralingoViewModel

    @State private var exporting = false
    @State private var backupJson = ""
    @State private var importing = false
    @State private var pendingImport: String?

    var body: some View {
        ProfileScreen(
            stats: app.stats,
            units: app.units,
            profile: app.profile,
            onGoal: viewModel.setDailyGoal,
            onExport: {
                backupJson = viewModel.exportJson()
                exporting = true
            },
            onImport: { importing = true },
        )
        .fileExporter(
            isPresented: $exporting,
            document: BackupDocument(json: backupJson),
            contentType: .json,
            defaultFilename: "infralingo-progress",
        ) { result in
            if case .success = result {
                viewModel.notice = "Backup saved."
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .plainText]) { result in
            let text: String?
            switch result {
            case .success(let url):
                let secured = url.startAccessingSecurityScopedResource()
                defer { if secured { url.stopAccessingSecurityScopedResource() } }
                text = try? String(contentsOf: url, encoding: .utf8)
            case .failure:
                text = nil
            }
            if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                pendingImport = text
            } else {
                viewModel.notice = "That file could not be read."
            }
        }
        .sheet(item: $pendingImport) { raw in
            ReplaceProgressSheet(
                onReplace: {
                    viewModel.importJson(raw)
                    pendingImport = nil
                },
                onCancel: { pendingImport = nil },
            )
            .presentationDetents([.large])
        }
    }
}

extension String: Identifiable {
    public var id: String { self }
}

/// A text document wrapper so `.fileExporter` can write the backup.
struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    let json: String

    init(json: String) {
        self.json = json
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        json = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(json.utf8))
    }
}
