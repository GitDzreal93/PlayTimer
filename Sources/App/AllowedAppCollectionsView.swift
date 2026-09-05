import FamilyControls
import SwiftUI

struct AllowedAppCollectionsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var isAppPickerPresented = false
    @State private var appPickerSelection = FamilyActivitySelection()
    @State private var pickerTargetID: UUID?
    @State private var renameTargetID: UUID?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    fallbackRow

                    ForEach(model.allowedAppCollections) { collection in
                        collectionRow(collection)
                    }

                    Button {
                        model.createAllowedAppCollection(name: "")
                    } label: {
                        Label("新建 App 合集", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 8)
                }
                .padding(24)
            }
            .navigationTitle("App 合集")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .familyActivityPicker(
            headerText: "选择这个合集允许使用的 App",
            footerText: "当前版本只保存 App，类别和网站选择会被忽略。",
            isPresented: $isAppPickerPresented,
            selection: $appPickerSelection
        )
        .onChange(of: isAppPickerPresented) { isPresented in
            guard !isPresented, let pickerTargetID else { return }
            model.updateAllowedAppSelection(appPickerSelection, for: pickerTargetID)
            self.pickerTargetID = nil
        }
        .alert("重命名合集", isPresented: renameAlertBinding) {
            TextField("合集名称", text: $renameText)
            Button("取消", role: .cancel) {
                renameTargetID = nil
                renameText = ""
            }
            Button("保存") {
                if let renameTargetID {
                    model.renameAllowedAppCollection(renameTargetID, name: renameText)
                }
                renameTargetID = nil
                renameText = ""
            }
        }
    }

    private var fallbackRow: some View {
        Button {
            model.selectAllowedAppCollection(nil)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: model.selectedAllowedAppCollection == nil ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(.teal)

                VStack(alignment: .leading, spacing: 4) {
                    Text("不使用 App 合集")
                        .font(.headline)
                    Text("开始后按全部 App / 网页实际使用计时")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func collectionRow(_ collection: AllowedAppCollection) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Button {
                    model.selectAllowedAppCollection(collection.id)
                } label: {
                    Image(systemName: isSelected(collection) ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.teal)

                VStack(alignment: .leading, spacing: 4) {
                    Text(collection.name)
                        .font(.headline)
                    Text("\(collection.applicationCount) 个 App")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Button {
                    model.selectAllowedAppCollection(collection.id)
                    pickerTargetID = collection.id
                    appPickerSelection = collection.selection
                    isAppPickerPresented = true
                } label: {
                    Label("编辑 App", systemImage: "square.grid.2x2")
                }
                .buttonStyle(.bordered)

                Button {
                    renameTargetID = collection.id
                    renameText = collection.name
                } label: {
                    Label("重命名", systemImage: "pencil")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    model.deleteAllowedAppCollection(collection.id)
                } label: {
                    Label("删除", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.regular)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(
            get: { renameTargetID != nil },
            set: { isPresented in
                if !isPresented {
                    renameTargetID = nil
                    renameText = ""
                }
            }
        )
    }

    private func isSelected(_ collection: AllowedAppCollection) -> Bool {
        model.settings.selectedAllowedAppCollectionID == collection.id
    }
}
