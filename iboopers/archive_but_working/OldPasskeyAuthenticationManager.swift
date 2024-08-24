//
//  PasskeyAuthenticationManager.swift
//  iboopers
//
//  Created by Ariel Klevecz on 8/6/24.
//

import AuthenticationServices
import SwiftUI

class OldPasskeyAuthenticationManager: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    @Published var errorMessage: String?
    
    static let shared = OldPasskeyAuthenticationManager()
    let domain = "boopers.yaytso.art"
    var currentUsername = ""
    var currentUserId = ""
    
    @Published var currentUser: User?
    
    private override init() {
        super.init()
        loadUser()
    }
    
    func registerNewAccount(username: String, uuid: String) {
        Task {
            do {
//                // DO VERIFICATION IN PRODUCTION
//                let isVerified = try await verifySignature(signature: uuid, message: username)
//                if (!isVerified) {
//                    throw NSError(domain: "RegistrationError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Signature verification failed"])
//                }
                let challenge = try await fetchChallenge(username: username)
                print("Register challange \(challenge)")
                let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: domain)
                print(uuid)
                print(username)
                // USE THE SIGNED UUID IN PRODUCTION?
                let userID = uuid.data(using: .utf8)!
                // let userID = "meepoman".data(using: .utf8)!
                let registrationRequest = publicKeyCredentialProvider.createCredentialRegistrationRequest(challenge: challenge, name: username, userID: userID)
                let authController = ASAuthorizationController(authorizationRequests: [registrationRequest])
                currentUsername = username
                currentUserId = userID.base64EncodedString()
                authController.delegate = self
                authController.presentationContextProvider = self
                authController.performRequests()
                
                await MainActor.run {
                    self.errorMessage = nil
                }
                
            } catch {
                await MainActor.run {
                    print("ERROR")
                    self.errorMessage = error.localizedDescription
                }
                print("Registration failed: \(error.localizedDescription)")
            }
        }
    }
    
    // They will sign in with their existing passkey
    // Their existing passkey has the credentialID that we will use to fetch their information
    // We create at temp "username" for the challenge, so this function probably doesn't need a username param
    func signIn(username:String) {
        Task {
            do {

                let randomChallenge = UUID().uuidString
                let challenge = try await fetchChallenge(username: randomChallenge)
                print("RPID used for registration/authentication: \(domain)")
                let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: domain)
                let assertionRequest = publicKeyCredentialProvider.createCredentialAssertionRequest(challenge: challenge)
                currentUsername = randomChallenge
                print("Raw challenge data: \(challenge)")
                let credential = try await performRequest(assertionRequest)
                
                if let assertion = credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
                    // let userID = assertion.userID.base64EncodedString()
//                    let user = User(id: userID, username: "")  // Username might not be available
//                    await MainActor.run {
//                        print(user)
//                        self.currentUser = user
//                        self.saveUser(user)
//                    }
                }
            } catch {
                print("Sign in failed: \(error.localizedDescription)")
            }
        }
    }
    
    private var continuations: [CheckedContinuation<ASAuthorizationCredential, Error>] = []

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {

        
//        continuations.removeFirst().resume(returning: authorization.credential)
        
        if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
            guard let attestationObject = credential.rawAttestationObject else {return}
//               let clientDataJSON = credential.rawClientDataJSON
            Task {
                try await sendRegistrationDataToServer(username: currentUsername, credential: credential)
                currentUsername = ""
                currentUserId = ""
            }
            let user = AppUser(id: currentUserId, username: currentUsername, authType: AuthType.passKey)
            UserManager.shared.updateUser(user)

       } else if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
           Task {
               let token = try await sendAssertionToServer(assertion: credential, username:currentUsername)
               AuthenticationManager.shared.storeToken(token)
               AuthenticationManager.shared.login(authType:AuthType.passKey)
               print(token)
           }
       } else {
       }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        continuations.removeFirst().resume(throwing: error)
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.windows.first!
    }
    
    func signOut() {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: "CurrentUser")
        AuthenticationManager.shared.deleteToken()
    }
    
    private func fetchChallenge(username: String) async throws -> Data {
        let url = URL(string: "https://\(domain)/auth/challenge?username=\(username)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONDecoder().decode(ChallengeResponse.self, from: data)
        print(json)
        return Data(base64Encoded: json.challenge)!
    }
    
    private func verifySignature(signature: String, message: String) async throws -> Bool {
        var urlComponents = URLComponents(string: "https://\(domain)/auth/verify")!
        urlComponents.queryItems = [
            URLQueryItem(name: "signature", value: signature),
            URLQueryItem(name: "message", value: message)
        ]
        
        guard let url = urlComponents.url else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONDecoder().decode(VerifyResponse.self, from: data)
        return json.isVerified
    }
    
    private func performRequest(_ request: ASAuthorizationRequest) async throws -> ASAuthorizationCredential {
        return try await withCheckedThrowingContinuation { continuation in
            let authController = ASAuthorizationController(authorizationRequests: [request])
            authController.delegate = self
            authController.presentationContextProvider = self
            authController.performRequests()
            
            self.continuations.append(continuation)
        }
    }
    
    private func sendRegistrationDataToServer(username: String, credential: ASAuthorizationPlatformPublicKeyCredentialRegistration) async throws {
        let url = URL(string: "https://\(domain)/register")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = [
            "username": username,
            "attestationObject": credential.rawAttestationObject!.base64EncodedString(),
            "clientDataJSON": credential.rawClientDataJSON.base64EncodedString(),
            "credentialId" : credential.credentialID.base64EncodedString()
        ]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "ServerError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to send registration data to server"])
        }
    }
    
    private func sendAssertionToServer(assertion: ASAuthorizationPlatformPublicKeyCredentialAssertion, username: String) async throws -> String {
            let url = URL(string: "https://\(domain)/auth-passkey/verify")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        
            let body: [String: Any] = [
                "username": username,
                "id": assertion.credentialID.base64EncodedString(),
                "rawId": assertion.credentialID.base64EncodedString(),
                "response": [
                    "authenticatorData": assertion.rawAuthenticatorData.base64EncodedString(),
                    "clientDataJSON": assertion.rawClientDataJSON.base64EncodedString(),
                    "signature": assertion.signature.base64EncodedString()
                ],
                "type": "public-key",
                "clientExtensionResults": [:] // Add any client extensions if used
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw NSError(domain: "ServerError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to verify assertion"])
            }
            
            let json = try JSONDecoder().decode(VerifyResponse.self, from: data)
            if !json.isVerified {
                throw AuthenticationError.unverifiedToken
            }
            
            return json.token
        }
    
    
    private func saveUser(_ user: User) {
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: "CurrentUser")
        }
    }
    
    private func loadUser() {
        if let userData = UserDefaults.standard.data(forKey: "CurrentUser"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            print(user)
            self.currentUser = user
        }
    }
}

struct User: Codable {
    let id: String
    let username: String
}

//struct ChallengeResponse: Codable {
//    let challenge: String
//}

//struct VerifyResponse: Codable {
//    let isVerified: Bool
//}
//#Preview {
//    AuthenticationView()
//}
