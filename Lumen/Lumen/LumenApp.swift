import SwiftUI
import SwiftData

@main
struct LumenApp: App {
    @StateObject private var authManager = AuthManager()
    private let groqService = GroqService()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Note.self,
            ChatMessageModel.self
        ])
        let modelConfiguration = ModelConfiguration(
            "iCloud.com.ayaangrover.Lumen"
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isUserLoggedIn {
                    HomeScreenView()
                } else {
                    LoginView { name, email in
                        authManager.login(name: name, email: email)
                    }
                }
            }
            .onAppear {
                Task {
                    await groqService.testGenericAPIConnection()
                }
            }
        }
        .modelContainer(sharedModelContainer)
        .environmentObject(authManager)
    }
}
