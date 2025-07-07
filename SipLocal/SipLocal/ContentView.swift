//
//  ContentView.swift
//  SipLocal
//
//  Created by Tarek Sakakini on 7/7/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo section
                VStack(spacing: 20) {
                    // App logo - using system image as placeholder until logo is added to assets
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    // App name
                    Text("SipLocal")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                }
                
                Spacer()
                
                // Buttons section
                VStack(spacing: 20) {
                    // Login button
                    Button(action: {
                        // TODO: Handle login action
                        print("Login tapped")
                    }) {
                        Text("Login")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(25)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    }
                    
                    // Sign up button
                    NavigationLink(destination: SignupView()) {
                        Text("Sign Up")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.white)
                            .cornerRadius(25)
                            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Footer text
                Text("Discover local flavors")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                                         .padding(.bottom, 30)
             }
         }
         }
     }
}

#Preview {
    ContentView()
}
