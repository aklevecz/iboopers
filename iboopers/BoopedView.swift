import SwiftUI
import AVFoundation

struct BoopedView: View {
    let boopContent: String
    @State private var audioPlayer: AVAudioPlayer?
    
    @State private var eggInfo: String?
    @State private var eggMessage: String?
    @State private var eggMessage2: String?

    @State private var imageScale: CGFloat = 0.5 // Initial scale for the bounce effect
    
    func playBoopSound() {
        guard let soundURL = Bundle.main.url(forResource: "boop", withExtension: "mp3") else {
            print("Sound file not found")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.play()
        } catch {
            print("Couldn't play sound: \(error)")
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HeadlineText(content:"Booped!")
            Text(eggInfo ?? "...")
                .font(.system(size:34))
                .fontWeight(.semibold)
//                .foregroundColor(Color("AccentColor"))
//            Text(eggMessage ?? "Egg Message")
//            Spacer()
            if let eggInfo = eggInfo, let color = eggInfo.split(separator: "-").first {
                Image("egg-token-\(color)-large-svg")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(imageScale)
                    .onAppear {
                        withAnimation(.interpolatingSpring(stiffness: 50, damping: 5)) {
                            imageScale = 1.0
                        }
                    }
            } else {
                Image("smiler-large-svg")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(imageScale)
                    .onAppear {
                        withAnimation(.interpolatingSpring(stiffness: 50, damping: 5)) {
                            imageScale = 1.0
                        }
                    }
            }
            Text(eggMessage ?? "")
                .font(.system(size: 24, weight: .semibold))
                .multilineTextAlignment(.center)
                .padding()
                .background(
//                    RoundedRectangle(cornerRadius: 10)
//                        .stroke(Color.primary, lineWidth: 2)
                )
            Text(eggMessage2 ?? "")
                .font(.system(size: 24, weight: .semibold))
                .multilineTextAlignment(.center)
                .padding()
                .foregroundColor(Color("AccentColor"))
                .background(
//                    RoundedRectangle(cornerRadius: 10)
//                        .stroke(Color.primary, lineWidth: 2)
                )
            
            Spacer()
            
        }
        .padding()
        .foregroundColor(.primary)
        .background(Color(UIColor.systemBackground))
        .onAppear {
            playBoopSound()
            eggMessage = "Looks like you already have this egg. Nice try!"

            if boopContent.starts(with: "iboopers://0xegg") {
                let (bid, signature) = extractParameters(from: boopContent)
                if let bid = bid, let signature = signature {
                    Task {
                        do {
                            let collectedEggInfo = try await EggManager.shared.collectEgg(message: bid, signature: signature)
                            print(collectedEggInfo.message)
                            eggInfo = collectedEggInfo.egg
                            
                            if collectedEggInfo.message == "Already collected" {
                                eggMessage = "Looks like you already have this egg. Nice try!"
                            } else if collectedEggInfo.message == "Collected" {
                                let color = String(collectedEggInfo.egg.split(separator: "-")[0])
                                if let points = colorPoints[color] {
                                    eggMessage = "Boop Successful!"
                                    eggMessage2 = "+\(points) points!"
                                }
                            } else {
                                eggMessage = collectedEggInfo.message
                            }
                            
                            print("Successfully collected egg:")
                            print("  Egg: \(collectedEggInfo.egg)")
                            print("  Message: \(collectedEggInfo.message)")
                        } catch EggErrors.invalidEgg {
                            print("Invalid egg error")
                            eggMessage = EggErrors.invalidEgg.localizedDescription
                        } catch AuthErrors.notAuthed {
                            eggMessage = AuthErrors.notAuthed.localizedDescription
                        } catch {
                            print("Error collecting egg: \(error)")
                            //AuthError
                            eggMessage = error.localizedDescription
                        }
                    }
                } else {
                    print("Failed to extract parameters")
                }
            } else {
                print("DOES NOT BEGIN WITH EGG")
            }
        }
        .onChange(of: boopContent) { _, newBoop in
            print("new boop")
            // add collecting logic here too
        }
//        .onDisappear {
//            // clear boopContent on dismiss
//            boopContent = ""
//        }
    }
    
    func extractParameters(from urlString: String) -> (bid: String?, signature: String?) {
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            print("Invalid URL string")
            return (nil, nil)
        }
        print(url)
        let bid = components.queryItems?.first(where: { $0.name == "bid" })?.value
        let signature = components.queryItems?.first(where: { $0.name == "signature" })?.value?.removingPercentEncoding
        
        return (bid, signature)
    }
}

#Preview {
    BoopedView(boopContent: "Frogman")
}
