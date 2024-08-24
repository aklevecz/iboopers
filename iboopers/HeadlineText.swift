//
//  HeadlineText.swift
//  iboopers
//
//  Created by Ariel Klevecz on 8/6/24.
//

import SwiftUI

struct HeadlineText: View {
    let content: String
    
    var body: some View {
        Text(content)
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding()
            .cornerRadius(10)
    }
}

#Preview {
    HeadlineText(content:"HEADLINE")
}
