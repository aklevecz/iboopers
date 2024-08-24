//
//  ContentView.swift
//  iboopers
//
//  Created by Ariel Klevecz on 8/4/24.
//

import SwiftUI


struct ContentView: View {
    @Environment(ModelData.self) var modelData
    @State private var boopContent: String?
    @State private var selectedTab = 0
    @State private var urlData: String?
    @State private var showBoopedView = false
    let nfcReaderWriter = NFCReaderWriter()

    var body: some View {
        TabView(selection: $selectedTab) {
            BoopingView(showBoopedView: $showBoopedView, boopContent: $boopContent)
                .tabItem {
                    Image("egg-token-svg")
                }.tag(0)
            AuthenticationView(urlData: Binding(
                get: { urlData ?? "" },
                set: { urlData = $0.isEmpty ? nil : $0 }))
                .tabItem {
                    Image("smiler-svg-64")
                }.tag(1)
                .onDisappear {
                    boopContent = nil
                    print("AUTH VIEW DISMISSED")
                }
            }
            .sheet(isPresented: $showBoopedView) {
                // BOOPED VIEW - CURRENT ONLY HANDLES POINT EGGS
                if let content = boopContent {
                        BoopedView(boopContent: content)
                        .onDisappear {
                            boopContent = nil
                        }
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 50, height: 50)
                            .onTapGesture {
                                showBoopedView = false
                                boopContent = nil
                                selectedTab = 1
                                print("ContentView: Dismissed BoopedView, boopContent reset to nil")
                            }
                            .padding()
                } else {
                    Text("No boop content available")
                        .onAppear {
                            print("ContentView: BoopedView appeared with nil boopContent")
                        }
                }
            }
            .onChange(of: boopContent) { oldValue, newBoopContent in
                if let content = boopContent {
                    // GO TO AUTH FROM A IN APP BOOP
                    if content.starts(with: "iboopers://0xbooper") {
                        selectedTab = 1
                        urlData = content
                    }
                }
                print("ContentView: boopContent changed from \(oldValue ?? "nil") to \(newBoopContent ?? "nil")")
            }
            .onChange(of: showBoopedView) { oldValue, newValue in
                print("ContentView: showBoopedView changed to \(newValue), boopContent: \(boopContent ?? "nil")")
            }
            .onOpenURL(perform: { url in
                // URLDATA TRIGGERS AUTHENTICATIONVIEW NAVIGATION
                urlData = url.absoluteString
                // IF POINT EGG
                if urlData?.starts(with: "iboopers://0xegg") == true {
                    boopContent = urlData
                    // TRIGGERS ONCHANGE FOR SHEET WITH SHOWBOOPEDVIEW
                    showBoopedView = true
                // IF AUTH EGG
                } else if urlData?.starts(with: "iboopers://0xbooper") == true {
                    // GOES TO AUTHENTICATION VIEW
                    selectedTab = 1
                }
            })
        }
}

#Preview {
    ContentView().environment(ModelData())
}
