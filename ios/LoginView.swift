import SwiftUI

/// Sign-in / create-account sheet backed by `SessionManager` (which talks to the
/// meal-tracker-web auth-service). Presented from Settings → Account.
struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SessionManager

    private enum Mode { case signIn, signUp }

    @State private var mode: Mode = .signIn
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    private var primaryTitleKey: LocalizedStringKey {
        mode == .signIn ? "login.sign_in" : "login.create_account"
    }

    private var canSubmit: Bool {
        !isSubmitting
            && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !password.isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("", selection: $mode) {
                        Text(LocalizedStringKey("login.sign_in")).tag(Mode.signIn)
                        Text(LocalizedStringKey("login.create_account")).tag(Mode.signUp)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    TextField(LocalizedStringKey("login.email"), text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    SecureField(LocalizedStringKey("login.password"), text: $password)
                        .textContentType(mode == .signIn ? .password : .newPassword)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        submit()
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                            } else {
                                Text(primaryTitleKey)
                            }
                            Spacer()
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
            .navigationTitle(primaryTitleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("cancel")) { dismiss() }
                }
            }
        }
    }

    private func submit() {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                switch mode {
                case .signIn:
                    try await session.login(email: email, password: password)
                case .signUp:
                    try await session.signup(email: email, password: password)
                }
                isSubmitting = false
                dismiss()
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                isSubmitting = false
            }
        }
    }
}
