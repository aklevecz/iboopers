//
//  BoopingView.swift
//  iboopers
//
//  Created by Ariel Klevecz on 8/6/24.
//

import SwiftUI
import UIKit

struct BoopingView: View {
//    @State private var boopContent: String?
    @State private var showTagDetail = false
    @Binding var showBoopedView: Bool
    @Binding var boopContent: String?
    @State private var showCTA = true
    @State private var eggColor: String = "yellow"  // Default color

    let nfcReaderWriter = NFCReaderWriter()
    @GestureState private var isPressed = false

    func generateHapticFeedback() {
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
    }
    
    func randomEggColor() -> String {
        let colors = ["red", "green", "yellow", "blue"]
        return colors.randomElement() ?? "yellow"
    }
    
    var body: some View {
//        NavigationStack {
            VStack {
//                HeadlineText(content:"Booping")

                Spacer()
                
                if showCTA {
                    HeadlineText(content: "Tap to Boop")
                }
//                Button(action: {
//                nfcReaderWriter.beginScanning { content in
//                    self.boopContent = content
//                    self.showTagDetail = true
//                }
//                }) {
                Image("egg-token-\(eggColor)-large-svg")
                        .resizable()
                        .frame(width: 300, height: 300)
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isPressed)
                        .gesture(
                        DragGesture(minimumDistance: 0)
                        .updating($isPressed) { (_, state, _) in
                           state = true
                            generateHapticFeedback()
                        }
                        .onEnded { _ in
                            showCTA = false
                           nfcReaderWriter.beginScanning { content in
                               print("Booping view \(content)")
                               DispatchQueue.main.async {
                                   self.boopContent = content
                                   if content.starts(with: "iboopers://0xegg") {
                                       self.showBoopedView = true
                                   }
                               }
                           }
                        }
                        )
//                }
//                .buttonStyle(PlainButtonStyle())

                Spacer()
//                CustomButton(title: "Boop") {
//                    nfcReaderWriter.beginScanning { content in
//                        self.boopContent = content
//                        self.showTagDetail = true
//                    }
//                }
                
            }
            .onAppear {
                eggColor = randomEggColor()
            }
//            .onChange(of: boopContent) { _, newValue in
//                    if newValue != nil {
////                        showTagDetail = true
//                        showBoopedView = true
//                    }
//                }
            .sheet(isPresented: $showTagDetail) {
                if let content = boopContent {
                    BoopedView(boopContent: content)
                    Button("Dismiss") {
                        showTagDetail = false
                    }
                } else {
                    Text("No boop content available")
                }
            }
//            .navigationDestination(isPresented: $showTagDetail) {
//                if let content = boopContent {
//                    BoopedView(boopContent: content)
//                }
//            }
//        }
    }
}

//#Preview {
//    BoopingView()
//}
