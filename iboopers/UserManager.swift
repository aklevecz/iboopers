//
//  UserManager.swift
//  iboopers
//
//  Created by Ariel Klevecz on 8/6/24.
//
import SwiftUI
import Combine

enum AuthType: String, Codable {
    case card
    case passKey
}

struct AppUser: Codable, Equatable {
    let id: String
    let username: String
    var authType: AuthType
}

class UserManager: ObservableObject {
    static let shared = UserManager()
    
    @Published var currentUser: AppUser? {
        didSet {
            saveUser()
        }
    }
    
    private init() {
        loadUser()
    }
    
    private func saveUser() {
        if let encoded = try? JSONEncoder().encode(currentUser) {
            UserDefaults.standard.set(encoded, forKey: "CurrentUser")
        }
    }
    
    private func loadUser() {
//        self.currentUser = AppUser(id: "1", username: "ariel", authType: AuthType.card)
        if let userData = UserDefaults.standard.data(forKey: "CurrentUser"),
           let user = try? JSONDecoder().decode(AppUser.self, from: userData) {
            self.currentUser = user
        }
    }
    
    func signOut() {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: "CurrentUser")
        AuthenticationManager.shared.deleteToken()
        EggManager.shared.invalidateCache()
    }
    
    func updateUser(_ user: AppUser) {
        DispatchQueue.main.async {
            self.currentUser = user
        }
    }
    
//    func updateUserAuthType(_ authType: AuthType) {
//        DispatchQueue.main.async {
//            if var user = self.currentUser {
//                user.authType = authType
//                self.currentUser = user
//            }
//        }
//    }
}

//#Preview {
//    UserManager()
//}
