import SwiftUI

struct ToolbarShim: ViewModifier {
    let l: LocalizationManager
    let isEditing: Bool
    let isValid: Bool
    let forceEnableSave: Bool

    @Binding var showingSettings: Bool
    @Binding var showingDeleteConfirm: Bool

    let dismiss: DismissAction
    let save: () -> Void

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    // Show Cancel when creating a new meal; keep it when editing if desired
                    Button(l.localized("cancel")) {
                        dismiss()
                    }
                    .accessibilityIdentifier("toolbar_cancel")
                }

                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Settings
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityIdentifier("toolbar_settings")

                    // Delete (only when editing)
                    if isEditing {
                        Button(role: .destructive) {
                            showingDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityIdentifier("toolbar_delete")
                    }

                    // Save
                    Button(l.localized("save")) {
                        save()
                    }
                    .disabled(!(isValid || forceEnableSave))
                    .accessibilityIdentifier("toolbar_save")
                }
            }
    }
}

extension View {
    func toolbarShim(
        l: LocalizationManager,
        isEditing: Bool,
        isValid: Bool,
        forceEnableSave: Bool,
        showingSettings: Binding<Bool>,
        showingDeleteConfirm: Binding<Bool>,
        dismiss: DismissAction,
        save: @escaping () -> Void
    ) -> some View {
        self.modifier(ToolbarShim(
            l: l,
            isEditing: isEditing,
            isValid: isValid,
            forceEnableSave: forceEnableSave,
            showingSettings: showingSettings,
            showingDeleteConfirm: showingDeleteConfirm,
            dismiss: dismiss,
            save: save
        ))
    }
}
