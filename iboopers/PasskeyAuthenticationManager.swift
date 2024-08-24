import AuthenticationServices
import SwiftUI

class PasskeyAuthenticationManager: NSObject, ObservableObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    @Published var errorMessage: String?
    @Published var currentUser: AppUser?
    
    static let shared = PasskeyAuthenticationManager()
    let domain = "boopers.yaytso.art"
    
    private var registrationContinuation: CheckedContinuation<ASAuthorizationPlatformPublicKeyCredentialRegistration, Error>?
    private var signInContinuation: CheckedContinuation<ASAuthorizationPlatformPublicKeyCredentialAssertion, Error>?
     
    
    private override init() {
        super.init()
        loadUser()
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
    
    func registerNewAccount(username: String, uuid: String) async throws {
        print("calling registerNewAccount")
        do {
            let isVerified = try await verifySignature(signature: uuid, message: username)
            if (!isVerified) {
                print("registerNewAccout isVerified has failed")
                throw NSError(domain: "RegistrationError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Signature verification failed"])
            }
            print("registerNewAccount isVerified: \(isVerified)")
            let challenge = try await fetchChallenge(username: username)
            let credential = try await performRegistration(username: username, uuid: uuid, challenge: challenge)
            let token = try await sendRegistrationDataToServer(username: username, credential: credential)
            AuthenticationManager.shared.storeToken(token)
            AuthenticationManager.shared.login(authType: AuthType.passKey)
//            UserManager.shared.updateUserAuthType(AuthType.passKey)
            // let user = AppUser(id: uuid, username: username)
            // UserManager.shared.updateUser(user)
            // await MainActor.run {
            //     // self.currentUser = user
            //     self.errorMessage = nil
            // }
        } catch {
//                await MainActor.run {
//                    self.errorMessage = error.localizedDescription
//                }
            print("Registration failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func performRegistration(username: String, uuid: String, challenge: Data) async throws -> ASAuthorizationPlatformPublicKeyCredentialRegistration {
        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: domain)
        let userID = uuid.data(using: .utf8)!
        let registrationRequest = publicKeyCredentialProvider.createCredentialRegistrationRequest(challenge: challenge, name: username, userID: userID)
        
        return try await withCheckedThrowingContinuation { continuation in
            self.registrationContinuation = continuation
            let authController = ASAuthorizationController(authorizationRequests: [registrationRequest])
            authController.delegate = self
            authController.presentationContextProvider = self
            authController.performRequests()
        }
    }
    
    func signIn() async throws {
        do {
            let randomChallenge = UUID().uuidString
            let challenge = try await fetchChallenge(username: randomChallenge)
            let credential = try await performSignIn(challenge: challenge)
            let token = try await sendAssertionToServer(assertion: credential, username: randomChallenge)
            AuthenticationManager.shared.storeToken(token)
            AuthenticationManager.shared.login(authType: AuthType.passKey)
//            UserManager.shared.updateUserAuthType(AuthType.passKey)
        } catch {
            print("Sign in failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func performSignIn(challenge: Data) async throws -> ASAuthorizationPlatformPublicKeyCredentialAssertion {
        let publicKeyCredentialProvider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: domain)
        let assertionRequest = publicKeyCredentialProvider.createCredentialAssertionRequest(challenge: challenge)
        
        return try await withCheckedThrowingContinuation { continuation in
            self.signInContinuation = continuation
            let authController = ASAuthorizationController(authorizationRequests: [assertionRequest])
            authController.delegate = self
            authController.presentationContextProvider = self
            authController.performRequests()
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration {
            registrationContinuation?.resume(returning: credential)
        } else if let credential = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
            signInContinuation?.resume(returning: credential)
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        registrationContinuation?.resume(throwing: error)
        signInContinuation?.resume(throwing: error)
    }
    
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.windows.first!
    }
    
    private func fetchChallenge(username: String) async throws -> Data {
        let url = URL(string: "https://\(domain)/auth/challenge?username=\(username)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONDecoder().decode(ChallengeResponse.self, from: data)
        return Data(base64Encoded: json.challenge)!
    }
    
    private func sendRegistrationDataToServer(username: String, credential: ASAuthorizationPlatformPublicKeyCredentialRegistration) async throws -> String {
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
        
        let (data, response) = try await URLSession.shared.data(for: request)
        print("sendRegistrationDataToServer response \(response)")
        print("sendRegistrationDataToServer data \(data)")
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "ServerError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to send registration data to server"])
        }
        let json = try JSONDecoder().decode(VerifyResponse.self, from: data)
        if !json.isVerified {
            throw AuthenticationError.unverifiedToken
        }
        
        return json.token
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
    
    func signOut() {
//        currentUser = nil
        UserDefaults.standard.removeObject(forKey: "CurrentUser")
        AuthenticationManager.shared.deleteToken()
    }
    
    private func loadUser() {
        if let userData = UserDefaults.standard.data(forKey: "CurrentUser"),
           let user = try? JSONDecoder().decode(AppUser.self, from: userData) {
//            self.currentUser = user
        }
    }
}

struct ChallengeResponse: Codable {
    let challenge: String
}

//struct VerifyResponse: Codable {
//    let isVerified: Bool
//    let token: String
//}
//
//enum AuthenticationError: Error {
//    case unverifiedToken
//}
