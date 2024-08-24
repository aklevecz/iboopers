//
//  AuthenticationManager.swift
//  iboopers
//
//  Created by Ariel Klevecz on 8/7/24.
//

import Foundation
import Security

enum AuthenticationError: Error {
    case unverifiedToken
    case invalidResponse
    case booperTaken
}
 
class AuthenticationManager {
    static let shared = AuthenticationManager()
    private init() {}
    
    private let tokenKey = "UserAccessToken"
    
    func register(signature: String, message: String) async throws {
        do {
            let response = try await createUserGetToken(signature: signature, message: message)
            storeToken(response.token)
            login(authType: AuthType.card)
        } catch {
            print("ERROR FETCHING TOKEN")
            throw error
        }
    }
    
    func login(authType: AuthType) {
        guard let token = getToken() else {return}
        let tokenParts = token.split(separator: ".")
        let name = String(tokenParts[0])
        let user = AppUser(id: name, username: name, authType: authType)
        UserManager.shared.updateUser(user)
    }
    
    func storeToken(_ token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }
    
    func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: tokenKey
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    // THIS ALSO CREATES A USER
    // PROBABLY CHANGE THIS TO POST
    func createUserGetToken(signature:String, message:String) async throws -> VerifyResponse {

        let domain = "boopers.yaytso.art"
        
        var urlComponents = URLComponents(string: "https://\(domain)/auth/create-user")!
        urlComponents.queryItems = [
            URLQueryItem(name: "signature", value: signature),
            URLQueryItem(name: "message", value: message)
        ]
        
        guard let url = urlComponents.url else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
            
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AuthenticationError.invalidResponse
        }
        
        let json = try JSONDecoder().decode(VerifyResponse.self, from: data)
        
        if !json.isVerified {
            if json.message == "BOOPER_TAKEN" {
                print("Error Booper Taken")
                throw AuthenticationError.booperTaken
            }
            throw AuthenticationError.unverifiedToken
        }
    
        return json
//        return json.token
    }
    
    func testToken() {
        Task {
            do {
                let url = URL(string: "https://boopers.yaytso.art/auth/test")!
                try await makeAuthenticatedRequest(url: url)
                
                // Decode the response
                //               let decoder = JSONDecoder()
                //               let response = try decoder.decode(TestTokenResponse.self, from: data)
                
                // Return true if the token is valid
                //               return response.isValid
            } catch {
                
            }
        }
    }
    
    func makeAuthenticatedRequest(url: URL, method: String = "GET") async throws -> Data {
        guard let token = getToken() else {
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No authentication token found"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "ServerError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Server returned an error"])
        }
        
        return data
    }
}
