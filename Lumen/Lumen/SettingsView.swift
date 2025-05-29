import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Account Details")) {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(authManager.userName.isEmpty ? "Not Available" : authManager.userName)
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(authManager.userEmail.isEmpty ? "Not Available" : authManager.userEmail)
                            .foregroundColor(.gray)
                    }
                }

                Section(header: Text("About")) {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("v1.0.0")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("Release Date")
                        Spacer()
                        Text("May 28, 2025")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("App Developer")
                        Spacer()
                        Text("Ayaan Grover")
                            .foregroundColor(.gray)
                    }
                }

                Section(header: Text("Data Management")) {
                    Button("Delete All My Data") {
                        showingDeleteConfirmation = true
                    }
                    .foregroundColor(.red)
                }
                
                Section {
                    Button("Sign Out") {
                        authManager.logout()
                        dismiss()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Close") {
                dismiss()
            })
            .alert("Are you sure you want to delete all your data?", isPresented: $showingDeleteConfirmation) {
                Button("Delete Everything", role: .destructive) {
                    deleteAllUserData()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action is irreversible. All your notes, chat history, and account details will be permanently deleted.")
            }
        }
    }

    private func deleteAllUserData() {
        do {
            try modelContext.delete(model: Note.self)
            try modelContext.delete(model: ChatMessageModel.self)
            try modelContext.save()
            print("All Note and ChatMessageModel data deleted from SwiftData for the current user.")
        } catch {
            print("Error deleting SwiftData content: \(error.localizedDescription)")
        }

        authManager.resetAllUserData()
        dismiss()
    }
}
