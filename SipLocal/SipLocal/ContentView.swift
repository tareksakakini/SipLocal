//
//  ContentView.swift
//  SipLocal
//
//  Created by Tarek Sakakini on 7/7/25.
//

import SwiftUI
import AVKit

struct LoopingVideoPlayer: UIViewRepresentable {
    @Binding var player: AVPlayer?

    class PlayerView: UIView {
        var playerLayer: AVPlayerLayer?

        override func layoutSubviews() {
            super.layoutSubviews()
            playerLayer?.frame = bounds
        }
    }

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.backgroundColor = .black

        if let player = player {
            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.videoGravity = .resizeAspectFill
            playerLayer.frame = view.bounds
            playerLayer.needsDisplayOnBoundsChange = true
            view.layer.addSublayer(playerLayer)
            view.playerLayer = playerLayer
        }

        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        if let player = player {
            if let playerLayer = uiView.playerLayer {
                playerLayer.player = player
                playerLayer.frame = uiView.bounds
            } else {
                let playerLayer = AVPlayerLayer(player: player)
                playerLayer.videoGravity = .resizeAspectFill
                playerLayer.frame = uiView.bounds
                playerLayer.needsDisplayOnBoundsChange = true
                uiView.layer.addSublayer(playerLayer)
                uiView.playerLayer = playerLayer
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var player: AVPlayer? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                if let player = player {
                    LoopingVideoPlayer(player: $player)
                        .ignoresSafeArea()
                } else {
                    Color.black.ignoresSafeArea()
                }

                // Dark overlay for readability
                Color.black.opacity(0.4)
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo section
                VStack(spacing: 20) {
                    Image("SipLocal_logo_white_on_transparent")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300, height: 300)
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                }
                
                Spacer()
                
                // Buttons section
                VStack(spacing: 20) {
                        Spacer().frame(height: 30) // Lower the buttons
                    NavigationLink(destination: LoginView().environmentObject(authManager)) {
                        Text("Login")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                                .frame(height: 55)
                            .background(Color.white.opacity(0.2))
                                .cornerRadius(27.5)
                            .overlay(
                                    RoundedRectangle(cornerRadius: 27.5)
                                    .stroke(Color.white, lineWidth: 1)
                            )
                    }
                    
                    NavigationLink(destination: SignupView().environmentObject(authManager)) {
                        Text("Sign Up")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                                .frame(height: 55)
                            .background(Color.white)
                                .cornerRadius(27.5)
                            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                Text("Discover local flavors")
                    .font(.subheadline)
                    .fontDesign(.rounded)
                    .foregroundColor(.white.opacity(0.8))
                                         .padding(.bottom, 30)
             }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onAppear(perform: setupPlayer)
         }
     }

    private func setupPlayer() {
        guard player == nil, let videoURL = getVideoURL() else { return }

        let playerItem = AVPlayerItem(url: videoURL)
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.isMuted = true
        newPlayer.actionAtItemEnd = .none

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            newPlayer.seek(to: .zero)
            newPlayer.play()
        }

        newPlayer.play()
        self.player = newPlayer
    }

    private func getVideoURL() -> URL? {
        let videoName = "signup_video"
        let fileManager = FileManager.default
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let cachedURL = cacheDirectory.appendingPathComponent("\(videoName).mp4")

        if fileManager.fileExists(atPath: cachedURL.path) {
            return cachedURL
        }

        guard let asset = NSDataAsset(name: videoName) else {
            print("Video asset '\(videoName)' not found.")
            return nil
        }

        do {
            try asset.data.write(to: cachedURL)
            return cachedURL
        } catch {
            print("Failed to write video data to cache: \(error)")
            return nil
        }
    }
}


#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
}
