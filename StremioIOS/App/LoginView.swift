import SwiftUI

/// Stremio account sign-in. On success the auth key is stored in the Keychain by
/// `AppSession` and the view is replaced by the library.
struct LoginView: View {
    @EnvironmentObject private var session: AppSession
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Stremio account") {
                    TextField("Email", text: $email)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }

                if let error = session.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                }

                Button(action: submit) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("Sign in")
                    }
                }
                .disabled(email.isEmpty || password.isEmpty || isSubmitting)
            }
            .navigationTitle("Sign in")
        }
    }

    private func submit() {
        Task {
            isSubmitting = true
            await session.login(email: email, password: password)
            isSubmitting = false
        }
    }
}
