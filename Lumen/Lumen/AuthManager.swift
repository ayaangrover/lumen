import Foundation
import Combine
import SwiftUI

class AuthManager: ObservableObject {
    @Published var isUserLoggedIn: Bool {
        didSet {
            UserDefaults.standard.set(isUserLoggedIn, forKey: "isUserLoggedIn")
        }
    }
    @Published var userName: String {
        didSet {
            UserDefaults.standard.set(userName, forKey: "userName")
        }
    }
    @Published var userEmail: String {
        didSet {
            UserDefaults.standard.set(userEmail, forKey: "userEmail")
        }
    }

    init() {
        self.isUserLoggedIn = UserDefaults.standard.bool(forKey: "isUserLoggedIn")
        self.userName = UserDefaults.standard.string(forKey: "userName") ?? ""
        self.userEmail = UserDefaults.standard.string(forKey: "userEmail") ?? ""
    }

    func login(name: String?, email: String?) {
        if let newName = name, !newName.isEmpty {
            self.userName = newName
        }
        if let newEmail = email, !newEmail.isEmpty {
            self.userEmail = newEmail
        }
        self.isUserLoggedIn = true
        print("User logged in: Name - \(self.userName), Email - \(self.userEmail)")
    }

    func logout() {
        self.isUserLoggedIn = false
        print("User logged out. User details are preserved.")
    }

    func resetAllUserData() {
        self.userName = ""
        self.userEmail = ""
        self.isUserLoggedIn = false

        UserDefaults.standard.removeObject(forKey: "userName")
        UserDefaults.standard.removeObject(forKey: "userEmail")
        UserDefaults.standard.removeObject(forKey: "isUserLoggedIn")

        print("All user data cleared from AuthManager and UserDefaults for the current user.")
    }
}
