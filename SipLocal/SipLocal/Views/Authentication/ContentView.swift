//
//  ContentView.swift
//  SipLocal
//
//  Created by Tarek Sakakini on 7/7/25.
//

import SwiftUI
import AVKit

// MARK: - Video Player Component

/// Custom video player that loops a background video for the welcome screen
struct LoopingVideoPlayer: UIViewRepresentable {
    @Binding var player: AVPlayer?

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.backgroundColor = .black
        view.setupPlayer(player)
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.updatePlayer(player)
    }
}

// MARK: - Player View Implementation

class PlayerView: UIView {
    var playerLayer: AVPlayerLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
    
    func setupPlayer(_ player: AVPlayer?) {
        guard let player = player else { return }
        
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.frame = bounds
        playerLayer.needsDisplayOnBoundsChange = true
        layer.addSublayer(playerLayer)
        self.playerLayer = playerLayer
    }
    
    func updatePlayer(_ player: AVPlayer?) {
        guard let player = player else { return }
        
        if let playerLayer = playerLayer {
            playerLayer.player = player
            playerLayer.frame = bounds
        } else {
            setupPlayer(player)
        }
    }
}

// MARK: - Welcome Screen

/// Welcome screen shown to unauthenticated users with login/signup options
/// Features a looping background video and branded interface
struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var player: AVPlayer? = nil
    
    // MARK: - Design Constants
    
    private enum Design {
        static let logoSize: CGFloat = 300
        static let buttonHeight: CGFloat = 55
        static let buttonCornerRadius: CGFloat = 27.5
        static let horizontalPadding: CGFloat = 40
        static let topSpacing: CGFloat = 150
        static let bottomSpacing: CGFloat = 30
        static let buttonSpacing: CGFloat = 20
        static let overlayOpacity: Double = 0.4
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background video or fallback
                backgroundView
                
                // Content overlay
                contentView
            }
            .onAppear(perform: setupPlayer)
            .onDisappear(perform: cleanupPlayer)
        }
    }
    
    // MARK: - View Components
    
    private var backgroundView: some View {
        ZStack {
            if let player = player {
                LoopingVideoPlayer(player: $player)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }
            
            // Dark overlay for text readability
            Color.black.opacity(Design.overlayOpacity)
                .ignoresSafeArea()
        }
    }
    
    private var contentView: some View {
        VStack {
            Spacer().frame(height: Design.topSpacing)
            
            logoSection
            
            Spacer()
            
            buttonsSection
            
            Spacer()
            
            taglineSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var logoSection: some View {
        Image("SipLocal_logo_white_on_transparent")
            .resizable()
            .scaledToFit()
            .frame(width: Design.logoSize, height: Design.logoSize)
            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
    }
    
    private var buttonsSection: some View {
        VStack(spacing: Design.buttonSpacing) {
            loginButton
            signupButton
        }
        .padding(.horizontal, Design.horizontalPadding)
    }
    
    private var loginButton: some View {
        NavigationLink(destination: LoginView()) {
            Text("Login")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: Design.buttonHeight)
                .background(Color.white.opacity(0.2))
                .cornerRadius(Design.buttonCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Design.buttonCornerRadius)
                        .stroke(Color.white, lineWidth: 1)
                )
        }
    }
    
    private var signupButton: some View {
        NavigationLink(destination: SignupView()) {
            Text("Sign Up")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .frame(height: Design.buttonHeight)
                .background(Color.white)
                .cornerRadius(Design.buttonCornerRadius)
                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
        }
    }
    
    private var taglineSection: some View {
        Text("Discover local flavors")
            .font(.subheadline)
            .fontDesign(.rounded)
            .foregroundColor(.white.opacity(0.8))
            .padding(.bottom, Design.bottomSpacing)
    }

    // MARK: - Video Management
    
    private func setupPlayer() {
        guard player == nil else { return }
        
        Task {
            do {
                let videoURL = try await loadVideoURL()
                await setupPlayer(with: videoURL)
            } catch {
                print("Failed to load background video: \(error)")
                // Continue without video - black background is already shown
            }
        }
    }
    
    @MainActor
    private func setupPlayer(with url: URL) async {
        let playerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: playerItem)
        
        // Configure player
        newPlayer.isMuted = true
        newPlayer.actionAtItemEnd = .none
        
        // Setup looping
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { _ in
            newPlayer.seek(to: .zero)
            newPlayer.play()
        }
        
        // Start playback
        newPlayer.play()
        self.player = newPlayer
    }
    
    private func cleanupPlayer() {
        player?.pause()
        player = nil
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    private func loadVideoURL() async throws -> URL {
        let videoName = "signup_video"
        let fileManager = FileManager.default
        
        // Check cache first
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let cachedURL = cacheDirectory.appendingPathComponent("\(videoName).mp4")
        
        if fileManager.fileExists(atPath: cachedURL.path) {
            return cachedURL
        }
        
        // Load from bundle and cache
        guard let asset = NSDataAsset(name: videoName) else {
            throw VideoError.assetNotFound(videoName)
        }
        
        do {
            try asset.data.write(to: cachedURL)
            return cachedURL
        } catch {
            throw VideoError.cachingFailed(error)
        }
    }
}

// MARK: - Video Error Handling

private enum VideoError: LocalizedError {
    case assetNotFound(String)
    case cachingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .assetNotFound(let name):
            return "Video asset '\(name)' not found in bundle"
        case .cachingFailed(let error):
            return "Failed to cache video: \(error.localizedDescription)"
        }
    }
}


// MARK: - Previews

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
}
