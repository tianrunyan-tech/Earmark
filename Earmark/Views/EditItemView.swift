import SwiftData
import SwiftUI

struct EditItemView: View {
    @Bindable var item: QueueItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("标题") {
                    TextField("标题", text: titleBinding, axis: .vertical)
                }
                Section("时长") {
                    DurationPicker(minutes: $item.durationMinutes)
                }
                Section("类型") {
                    Picker("类型", selection: modeBinding) {
                        ForEach(ListenMode.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("链接") {
                    Text(item.urlString)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .navigationTitle("编辑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { item.title },
            set: { newValue in
                item.title = newValue
                item.titleIsPlaceholder = false
            }
        )
    }

    private var modeBinding: Binding<ListenMode> {
        Binding(
            get: { item.mode },
            set: { newValue in
                item.mode = newValue
                item.modeIsUserSet = true
            }
        )
    }
}
