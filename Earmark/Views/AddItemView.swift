import SwiftData
import SwiftUI

struct AddItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var text = ""
    @State private var title = ""
    @State private var titleEdited = false
    @State private var minutes: Int?
    @State private var mode: ListenMode = .casual
    @State private var modeEdited = false
    @State private var errorMessage: String?

    private var parsed: ParsedShare? { LinkParser.parse(text) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("粘贴分享文字或链接", text: $text, axis: .vertical)
                        .lineLimit(2...5)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    PasteButton(payloadType: String.self) { strings in
                        guard let pasted = strings.first else { return }
                        Task { @MainActor in text = pasted }
                    }
                } header: {
                    Text("链接")
                } footer: {
                    if let parsed {
                        Label("识别到\(parsed.platform.displayName)链接", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if !text.isEmpty {
                        Text("没有识别到链接")
                            .foregroundStyle(.red)
                    }
                }

                Section("标题") {
                    TextField("自动识别，可修改", text: titleBinding, axis: .vertical)
                }

                Section("时长") {
                    DurationPicker(minutes: $minutes)
                }

                Section {
                    Picker("类型", selection: modeBinding) {
                        ForEach(ListenMode.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("类型")
                } footer: {
                    Text(modeEdited ? "" : "根据标题自动判断，可以手动改")
                }
            }
            .navigationTitle("添加待听")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(parsed == nil)
                }
            }
            .onChange(of: text) { _, _ in
                syncFromText()
            }
            .alert("没能添加", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好") {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { title },
            set: { newValue in
                title = newValue
                titleEdited = true
                if !modeEdited { mode = ModeClassifier.guess(title: newValue) }
            }
        )
    }

    private var modeBinding: Binding<ListenMode> {
        Binding(
            get: { mode },
            set: { newValue in
                mode = newValue
                modeEdited = true
            }
        )
    }

    private func syncFromText() {
        if !titleEdited {
            title = parsed?.titleHint ?? ""
        }
        if !modeEdited {
            mode = ModeClassifier.guess(title: title)
        }
    }

    private func save() {
        let result = ItemStore.add(
            text: text,
            title: title,
            minutes: minutes,
            mode: modeEdited ? mode : nil,
            in: context
        )
        switch result {
        case .added:
            dismiss()
        case .duplicate:
            errorMessage = "这条已经在待听列表里了"
        case .invalid:
            errorMessage = "没有识别到链接，请粘贴完整的分享文字或网址"
        }
    }
}

#Preview {
    AddItemView()
        .modelContainer(for: QueueItem.self, inMemory: true)
}
