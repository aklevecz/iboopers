//
//  AuthenticationView.swift
//  iboopers
//
//  Created by Ariel Klevecz on 8/6/24.
//
import SwiftUI

struct CustomTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 18, weight: .regular))
            .padding(.vertical, 5)
    }
}




struct AuthenticationView: View {
    @Environment(ModelData.self) var modelData
    @Binding var urlData: String
    @State private var username = ""
    @State private var uuid = ""
    
    @State private var isAuthing = false

    @State private var showingAlert = false
    @State private var errorMessage: String?
    
    @StateObject private var userManager = UserManager.shared
    @State private var rotationAngle: Double = 0
    



    var body: some View {
        ZStack {
            VStack {
                if let currentUser = userManager.currentUser {
                    ProfileView().padding()
                } else {
                    HeadlineText(content:"Got Boop?")
                    
                    Spacer()
                    
                    Image("smiler-large-svg").resizable().frame(width:200, height:200)
                        .rotationEffect(.degrees(rotationAngle)) // Apply rotation effect
                        .animation(isAuthing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: rotationAngle) // Animate rotation
                        .onAppear {
                            if isAuthing {
                                rotationAngle = 360
                            }
                        }
                        .onChange(of: isAuthing) { _, newValue in
                            if newValue {
                                rotationAngle = 360
                            } else {
                                rotationAngle = 0
                            }
                        }
                    
                    Text(!isAuthing ? "Find a booping card to begin your booping journey" : "Checking your boop...")
                        .font(.system(size: 34, weight: .bold, design: .rounded ))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                    //.multilineTextAlignment(.center)
                        .padding(50)
                    
                    Spacer()
                    
                    // CustomButton(title:"PASSKEY") {
                    //     PasskeyAuthenticationManager.shared.registerNewAccount(username: "Meepo", uuid: "hepno")
                    // }
                    Text("or Login if you already created a Passkey")
                        .padding(.horizontal, 100)
                        .multilineTextAlignment(.center)
                    CustomButton(title:"Login") {
                        isAuthing = true
                        Task {
                            do {
                                try await PasskeyAuthenticationManager.shared.signIn()
                                isAuthing = false
                            } catch {
                                print("ERROR IN LOGIN: \(error.localizedDescription)")
                                showingAlert = true
                                errorMessage = error.localizedDescription
                                isAuthing = false
                            }
                        }
                    }
                    .padding(.bottom, 50)
                    .disabled(isAuthing)
                    
                }
                
 
            }
        }
        .onAppear {
            handleURLIfPresent()
        }
        .onChange(of: urlData) { _, _ in
            handleURLIfPresent()
        }
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage ?? "An unknown error occurred"),
                dismissButton: .default(Text("OK"))
            )
        }
//        .onChange(of: authManager.errorMessage) { _, newError in
//            showingAlert = newError != nil
//        }
    }

    private func handleURLIfPresent() {

         guard !urlData.isEmpty,
           let url = URL(string: urlData),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
         if urlData.starts(with: "iboopers://0xbooper") == false {
            return
         }
        if let currentUser = userManager.currentUser {
            errorMessage = "Um you are already signed in"
            showingAlert = true
            urlData = ""
            return
        }
         username = components.queryItems?.first(where: { $0.name == "name" })?.value ?? url.lastPathComponent
         uuid = components.queryItems?.first(where: { $0.name == "signature" })?.value ?? ""
         isAuthing = true
         Task {
             do {
                 try await AuthenticationManager.shared.register(signature: uuid, message: username)
                 //                try await PasskeyAuthenticationManager.shared.registerNewAccount(username: username, uuid: uuid)
                 isAuthing = false
             } catch AuthenticationError.booperTaken {
                 showingAlert = true
                 errorMessage = "This Booper is already taken! Get your own dude"
                 isAuthing = false
             } catch {
                 print("Error in handleURLIfPresent: \(error.localizedDescription)")
                 showingAlert = true
                 errorMessage = error.localizedDescription
                 isAuthing = false

             }
         }
         // Clear the URL data after processing
         urlData = ""
     }
}

struct VerifyResponse: Codable {
    let isVerified: Bool
    let token: String
    let message: String
}

#Preview {
    struct PreviewContainer: View {
        @State private var urlData = ""
        
        var body: some View {
            AuthenticationView(urlData: $urlData).environment(ModelData())
        }
    }
    
    return PreviewContainer()
}
