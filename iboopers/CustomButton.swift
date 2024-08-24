//
//  CustomButton.swift
//  iboopers
//
//  Created by Ariel Klevecz on 8/6/24.
//

import SwiftUI

struct CustomButton: View {
    let title: String
    let action: () -> Void
    let backgroundColor: Color
    let fontSize = 20.0
    @Environment(\.colorScheme) var colorScheme

    init(title: String, backgroundColor: Color = .primary, action: @escaping () -> Void) {
        self.title = title
        self.backgroundColor = backgroundColor
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .foregroundColor(colorScheme == .light ? .white : .black)
                .padding()
                .frame(minWidth: 150)
                .background(colorScheme == .light ? Color.black : Color.white)
                .cornerRadius(50)
                .overlay(
                    RoundedRectangle(cornerRadius: 50)
                        .stroke(colorScheme == .light ? .white : .black, lineWidth: 2)
                        .padding(6)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
//#Preview {
//    BoopingView()
//}
