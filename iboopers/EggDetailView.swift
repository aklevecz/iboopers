import SwiftUI

struct EggDetailView: View {
    let eggId: String
    let color: String
    let createdAt: String
    
    @Environment(\.presentationMode) var presentationMode
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1.0

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Custom navigation bar
                HStack {
                    Button(action: {
                        self.presentationMode.wrappedValue.dismiss()
                    }) {
                        HStack {
                            Image(systemName: "arrow.left").foregroundColor(.red)
                            Image("smiler-svg-64")
                        }
                        .foregroundColor(.blue)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                Spacer()
                // Main content
                VStack(spacing: 20) {
                    
                    Text(eggId)
                        .font(.system(size:34))
                        .fontWeight(.bold)
                    Image("egg-token-\(color)-large-svg")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 250, height: 250)
                    

                    Text("\(color.capitalized)")
                        .font(.headline)
                    if let points = colorPoints[color] {

                        VStack {
                            Text("\(points)")
                                .font(.system(size:40, weight:.bold))
                                .foregroundColor(.green)
                            Text("Points")
                                .font(.system(size:20))
                                .foregroundStyle(.green)
                        }
                    }
                    
                    VStack {
                        Text("Acquired")
                            .font(.subheadline)
                        Text("\(formatDate(createdAt))")
                            .font(.subheadline)
                    }

                    
                }
                .padding()
                Spacer()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .offset(x: self.offset)
            .opacity(opacity)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if gesture.translation.width > 0 {
                            self.offset = gesture.translation.width
                            self.opacity = Double(1 - gesture.translation.width / geometry.size.width)
                        }
                    }
                    .onEnded { gesture in
                        if gesture.translation.width > geometry.size.width / 3 {
                            withAnimation {
                                self.offset = geometry.size.width
                                self.opacity = 0
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                self.presentationMode.wrappedValue.dismiss()
                            }
                        } else {
                            withAnimation {
                                self.offset = 0
                                self.opacity = 1
                            }
                        }
                    }
            )
        }
        .navigationBarHidden(true)
        .edgesIgnoringSafeArea(.top)
    }
    
    func formatDate(_ dateString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = dateFormatter.date(from: dateString) {
            dateFormatter.dateFormat = "MMMM d, yyyy"
            return dateFormatter.string(from: date)
        }
        return dateString
    }
}

#Preview {
    NavigationView {
        EggDetailView(eggId: "red-5", color: "red", createdAt: "2024-08-06 12:00:00")
    }
}
