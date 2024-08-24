//
//  ProfileSidebar.swift
//  iboopers
//
//  Created by Ariel Klevecz on 8/15/24.
//

import SwiftUI
struct BooperButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.black)
            .font(.system(size: 16, weight: .bold, design: .default))
            .padding()
            .background(Color.white)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}
struct ProfileSidebarView: View {
    @Binding var isOpen: Bool
    @Environment(\.colorScheme) var colorScheme
    @State private var notificationsEnabled = false

    var signOut: () -> Void
    var closeSidebar: () -> Void

    var body: some View {
        VStack {
            Text("Settings").font(.system(size:24, weight:.bold, design:.rounded)).padding(20)
            
            Text("Note: Under development") .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            
                .font(.system(size: 14, weight: .regular)) // Smaller font size for better fit
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
            
            VStack {
                Text("Notifications").font(.headline).padding(.horizontal)
                Toggle("Enable Notifications", isOn: $notificationsEnabled)
                    .padding(.horizontal, 30)
                if notificationsEnabled {
                    Text("Doesn't do anything... yet!")
                        .font(.subheadline)
                        .padding(.horizontal, 15)
                }
            }.padding(.bottom, 20)
            
//            Spacer()
            
            Text("Account").font(.headline).padding(.horizontal).padding(.bottom, 10)
            if UserManager.shared.currentUser?.authType == AuthType.passKey {
                Text("You have a PassKey account. Now you can login on any device!")
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if UserManager.shared.currentUser?.authType != AuthType.passKey {
                (Text("Register your account using PassKeys ") +
                                Text(Image(systemName: "key.fill")))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 10)
                
                Button("Register Passkey") {
                    Task {
                        do {
                            guard let token = AuthenticationManager.shared.getToken() else {return}
                            let username = String(token.split(separator:".")[0])
                            let uuid = String(token.split(separator: ".")[1])
                            print(username)
                            print(uuid)
                            try await PasskeyAuthenticationManager.shared.registerNewAccount(username: username, uuid: uuid)
                        } catch {
                            print("Passkey Registartion has failed")
                        }
                    }
                }
                .buttonStyle(BooperButtonStyle())
            }
            Spacer()
            if UserManager.shared.currentUser?.authType == AuthType.passKey {
                Button("Sign out") {
                    signOut()
                }
                .foregroundColor(.black)
                .underline()
                .font(.system(size: 16, weight: .bold, design: .default))
                .padding()
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black, lineWidth: 1)
                )
                .padding(.bottom, 50)
                
            }
            
            VStack {
                Text("Debugging")
                Button("Refresh Boops") {
                    EggManager.shared.invalidateCache()
                    Task {
                        try await EggManager.shared.getBoops()
                    }
                }

            }.buttonStyle(BooperButtonStyle()).padding(.bottom,40)
            
            Spacer()
            
            Button(action: {
                closeSidebar()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundColor(.primary)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.bottom, 30)


     }
        .frame(width: 280)
        .background(colorScheme == .dark ? Color.black : Color.white)
        .overlay(
            Rectangle()
                .stroke(colorScheme == .dark ? Color.white : Color.black, lineWidth: 2)
        )
    }
    struct RectangleWithoutBottom: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            return path
        }
    }
}

#Preview {
    struct PreviewContainer: View {
        @State private var isOpen = true
        
        var body: some View {
            ProfileSidebarView(
                isOpen: $isOpen,
                signOut: { print("Sign out tapped") },
                closeSidebar: {
                    print("Close sidebar tapped")
                    isOpen = false
                }
            )
            .environmentObject(UserManager.shared)
        }
    }
    
    return PreviewContainer()
}
