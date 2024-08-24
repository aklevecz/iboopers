//
//  ProfileView.swift
//  iboopers
//
//  Created by Ariel Klevecz on 8/6/24.
//

import SwiftUI

let colorPoints: [String: Int] = [
    "red": 100,
    "blue": 200,
    "green": 300,
    "yellow": 500,
    "black": 750,
    "darkness": 1000
]

let OFFSET_OPEN = 70.0
let OFFSET_CLOSED = 340.0

struct ProfileView: View {
    @ObservedObject private var userManager = UserManager.shared

    @State private var loading = true;

    @Environment(ModelData.self) var modelData
    
    @State private var boops: [BoopD1] = []
    @State private var computedEggPoints = 0
    
    @State private var gearRotation: Double = 0

    @State private var isSidebarOpen = false
    @State private var sidebarOffset: CGFloat = OFFSET_CLOSED

    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    if let currentUser = userManager.currentUser {
                        HStack {
                            Text(currentUser.username).font(.system(size: 32, weight:.bold))
                            Spacer()
                            Button(action: {
                                withAnimation(.linear(duration: 0.5)) {
                                    self.gearRotation += 360 // Rotate 360 degrees
                                }
                                if isSidebarOpen {
                                    closeSidebar()
                                } else {
                                    openSidebar()
                                }
                            }) {
                                Image(systemName: "gearshape.fill")
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.primary)
                                    .rotationEffect(.degrees(gearRotation))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 20)
                        //                List {
                        //                    ForEach(modelData.collection) { egg in
                        //                        HStack(spacing: 16) {
                        //                            Image("egg-token-64")
                        //                            VStack(alignment: .leading, spacing: 0) {
                        //                                Text(egg.name).font(.system(size:20, design: .rounded))
                        //                            }
                        //                        }
                        //                    }
                        //                }
                        //                .border(Color.white)
                        //                .listStyle(PlainListStyle())
                        //                .padding(20)
                        VStack {
                            Text("Points")
                            Text("\(computedEggPoints)").font(.system(size:30, weight:.bold, design:.rounded)).foregroundStyle(Color("AccentColor"))
                        }.padding(40)
                        Text("Boops").font(.system(size:24, weight:.bold, design:.rounded)) // Set to subheading
                            .frame(maxWidth: .infinity, alignment: .leading) // Align left
                            .padding(.leading, 20) // Optional: Add some padding to the left
                        List {
                            if loading {
                                VStack {
                                    Text("Loading your boops...").padding(.bottom, 20)
                                    HStack {
                                        Spacer()
                                        ProgressView().tint(.red).scaleEffect(3.0)
                                        Spacer()
                                    }
                                }
                            }
                            ForEach(boops) { boop in
                                NavigationLink(destination: EggDetailView(eggId: boop.id, color: String(boop.id.split(separator: "-")[0]), createdAt: boop.createdAt)) {
                                    HStack(spacing: 16) {
                                        Image("egg-token-\(boop.id.split(separator: "-")[0])-svg")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width:64)
                                        VStack(alignment: .leading, spacing: 0) {
                                            Text(boop.id).font(.system(size:16, design: .rounded)).padding(.leading, 20)
                                        }
                                        Spacer()
                                        Text(formatDate(boop.createdAt))
                                            .font(.system(size:11))
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                        .padding(10)
                    }
                }.onAppear {
                    Task {
                        do {
                            loading = true
                            let boopResponse = try await EggManager.shared.getBoops()
                            boops = boopResponse.boops
//                            boops = [BoopD1(id:"red-5",booperId:"ariel",category:"eggs",createdAt: "Jimuary13")]
                            computedEggPoints = calculateEggPoints(from: boops)
                            print("Boops: \(boops)")
                        } catch {
                            print(error)
                        }
                        loading = false
                    }
                }
                //            Color.black.opacity(isSidebarOpen ? 0.5 : 0)
                //                .ignoresSafeArea()
                //                .onTapGesture {
                //                    closeSidebar()
                //                }
                
                ProfileSidebarView(isOpen: $isSidebarOpen,
                                   signOut: {
                    userManager.signOut()
                    closeSidebar()
                },
                                   closeSidebar: closeSidebar)
                .opacity(0.95)
                .frame(height:600)
                .onChange(of: isSidebarOpen) { _, value in
                    print(value)
                }
                .offset(x: sidebarOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width > 0 {
                                //                                sidebarOffset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            if value.translation.width > 50 {
                                closeSidebar()
                            } else {
                                openSidebar()
                            }
                        }
                )
            }
        }
    }
    
    // BOOPED MESSAGING - You got X points, You got whatever egg, you already got this one, go to your profile
    // PROFILE - make points look nice, align the egg id
    private func openSidebar() {
        withAnimation {
            isSidebarOpen = true
//            sidebarOffset = 100
            sidebarOffset = OFFSET_OPEN
        }
    }
    
    private func closeSidebar() {
        withAnimation {
            isSidebarOpen = false
//            sidebarOffset = 320
            sidebarOffset = OFFSET_CLOSED
        }
    }

    func calculateEggPoints(from boops: [BoopD1]) -> Int {
        var totalPoints = 0
        for boop in boops {
            let color = String(boop.id.split(separator: "-")[0])
            if let points = colorPoints[color] {
                totalPoints += points
            }
        }
        return totalPoints
    }

    func formatDate(_ dateString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"  // Adjust the format to match your date string
        if let date = dateFormatter.date(from: dateString) {
            print("DATE?")
            dateFormatter.dateFormat = "MMMM d, yyyy" // Desired output format
            return dateFormatter.string(from: date)
        } else {
            print("NOT DATE?")
        }
        return dateString // Return original string if parsing fails
    }
}

#Preview {
    ProfileView().environment(ModelData())
}
