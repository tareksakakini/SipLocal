/**
 * ContentViewModel.swift
 * SipLocal
 *
 * ViewModel for ContentView following MVVM architecture.
 * Handles video loading, playback management, and navigation logic for the welcome screen.
 *
 * ## Responsibilities
 * - **Video Management**: Load, cache, and manage background video playback
 * - **Navigation Logic**: Handle login and signup navigation flows
 * - **Performance**: Optimize video loading and memory management
 * - **Error Handling**: Graceful fallbacks for video loading failures
 * - **Lifecycle Management**: Proper cleanup and resource management
 *
 * ## Architecture
 * - **ObservableObject**: Reactive state management with @Published properties
 * - **AVKit Integration**: Clean video player management and controls
 * - **Caching System**: Efficient video caching for performance
 * - **Error Boundaries**: Structured error handling with user-friendly fallbacks
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI
import AVKit
import Combine

// MARK: - ContentViewModel

/**
 * ViewModel for ContentView
 * 
 * Manages welcome screen video playback, navigation, and user interactions.
 * Provides reactive state management and clean separation of concerns.
 */
@MainActor
class ContentViewModel: ObservableObject {
    
    // MARK: - Published State Properties
    @Published var player: AVPlayer?
    @Published var isVideoLoading: Bool = true
    @Published var videoLoadError: VideoError?
    @Published var showLoginView: Bool = false
    @Published var showSignupView: Bool = false
    @Published var isPlayerReady: Bool = false
    
    // MARK: - Design Constants
    private enum Design {
        static let videoName: String = "signup_video"
        static let videoLoadTimeout: Double = 10.0
        static let playerSetupDelay: Double = 0.5
        static let cacheCleanupInterval: Double = 86400.0 // 24 hours
        static let maxCacheSize: Int64 = 100_000_000 // 100MB
        static let retryAttempts: Int = 3
        static let retryDelay: Double = 1.0
    }
    
    // MARK: - Private State
    private var videoLoadTask: Task<Void, Never>?
    private var playerObserver: NSObjectProtocol?
    private var retryCount: Int = 0
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// Returns whether the video is successfully loaded and playing
    var isVideoPlaying: Bool {
        guard let player = player else { return false }
        return player.rate > 0 && player.error == nil
    }
    
    /// Returns whether there's a video error
    var hasVideoError: Bool {
        videoLoadError != nil
    }
    
    /// Returns whether to show video or fallback background
    var shouldShowVideo: Bool {
        player != nil && !hasVideoError
    }
    
    /// Returns the current loading state description
    var loadingStateDescription: String {
        if isVideoLoading {
            return "Loading welcome video..."
        } else if hasVideoError {
            return "Video unavailable"
        } else if isPlayerReady {
            return "Ready"
        } else {
            return "Preparing video..."
        }
    }
    
    // MARK: - Initialization
    
    init() {
        setupVideoLoading()
        setupCacheManagement()
    }
    
    deinit {
        Task { @MainActor [weak self] in
            self?.cleanup()
        }
    }
    
    // MARK: - Public Interface
    
    /// Handle view appearing
    func handleViewAppear() {
        guard player == nil && !isVideoLoading else { return }
        loadVideo()
    }
    
    /// Handle view disappearing
    func handleViewDisappear() {
        pauseVideo()
    }
    
    /// Navigate to login view
    func navigateToLogin() {
        showLoginView = true
        print("🔑 Navigating to login")
    }
    
    /// Navigate to signup view
    func navigateToSignup() {
        showSignupView = true
        print("📝 Navigating to signup")
    }
    
    /// Retry video loading
    func retryVideoLoad() {
        guard retryCount < Design.retryAttempts else {
            print("❌ Maximum retry attempts reached for video loading")
            return
        }
        
        retryCount += 1
        videoLoadError = nil
        loadVideo()
    }
    
    /// Force reload video
    func reloadVideo() {
        cleanup()
        retryCount = 0
        loadVideo()
    }
    
    /// Pause video playback
    func pauseVideo() {
        player?.pause()
    }
    
    /// Resume video playback
    func resumeVideo() {
        player?.play()
    }
    
    /// Toggle video playback
    func toggleVideoPlayback() {
        guard let player = player else { return }
        
        if player.rate > 0 {
            pauseVideo()
        } else {
            resumeVideo()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupVideoLoading() {
        // Setup video loading on initialization
        loadVideo()
    }
    
    private func setupCacheManagement() {
        // Setup periodic cache cleanup
        Timer.scheduledTimer(withTimeInterval: Design.cacheCleanupInterval, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.cleanupVideoCache()
            }
        }
    }

    private func loadVideo() {
        videoLoadTask?.cancel()
        isVideoLoading = true
        videoLoadError = nil

        videoLoadTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let url = try await loadVideoURL()
                
                // Add setup delay for smooth transition
                try await Task.sleep(nanoseconds: UInt64(Design.playerSetupDelay * 1_000_000_000))
                
                await setupPlayer(with: url)
                
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.isVideoLoading = false
                    self.isPlayerReady = true
                    print("✅ Video loaded successfully")
                }

            } catch let error as VideoError {
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.isVideoLoading = false
                    self.videoLoadError = error
                    print("❌ Video loading failed: \(error.localizedDescription)")
                }

                // Auto-retry on certain errors
                if case .cachingFailed = error, self.retryCount < Design.retryAttempts {
                    try? await Task.sleep(nanoseconds: UInt64(Design.retryDelay * 1_000_000_000))
                    await MainActor.run { [weak self] in
                        self?.retryVideoLoad()
                    }
                }

            } catch {
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    self.isVideoLoading = false
                    self.videoLoadError = .cachingFailed(error)
                    print("❌ Video loading failed with unknown error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func setupPlayer(with url: URL) async {
        let playerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: playerItem)
        
        // Configure player for looping background video
        newPlayer.isMuted = true
        newPlayer.actionAtItemEnd = .none
        
        // Setup looping notification
        setupLoopingNotification(for: playerItem, player: newPlayer)
        
        // Setup player status observation
        setupPlayerObservation(for: newPlayer)
        
        // Start playback
        newPlayer.play()
        
        await MainActor.run { [weak self] in
            self?.player = newPlayer
        }
    }
    
    private func setupLoopingNotification(for item: AVPlayerItem, player: AVPlayer) {
        playerObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
            print("🔄 Video looped")
        }
    }
    
    private func setupPlayerObservation(for player: AVPlayer) {
        // Use modern observation instead of KVO
        Task { [weak self] in
            for await status in player.publisher(for: \.status).values {
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    switch status {
                    case .readyToPlay:
                        self.isPlayerReady = true
                        print("🎥 Player ready to play")
                    case .failed:
                        self.videoLoadError = .playbackFailed
                        print("❌ Player failed to play")
                    case .unknown:
                        print("⚠️ Player status unknown")
                    @unknown default:
                        print("⚠️ Unknown player status")
                    }
                }
            }
        }
    }
    
    private func loadVideoURL() async throws -> URL {
        let fileManager = FileManager.default
        
        // Check cache first
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let cachedURL = cacheDirectory.appendingPathComponent("\(Design.videoName).mp4")
        
        if fileManager.fileExists(atPath: cachedURL.path) {
            print("📹 Using cached video")
            return cachedURL
        }
        
        // Load from bundle and cache
        guard let asset = NSDataAsset(name: Design.videoName) else {
            throw VideoError.assetNotFound(Design.videoName)
        }
        
        do {
            try asset.data.write(to: cachedURL)
            print("📹 Video cached successfully")
            return cachedURL
        } catch {
            throw VideoError.cachingFailed(error)
        }
    }
    
    private func cleanupVideoCache() async {
        let fileManager = FileManager.default
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
            
            var totalSize: Int64 = 0
            var oldFiles: [(URL, Date)] = []
            
            for file in files {
                if file.pathExtension == "mp4" {
                    let resources = try file.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                    if let size = resources.fileSize, let date = resources.creationDate {
                        totalSize += Int64(size)
                        oldFiles.append((file, date))
                    }
                }
            }
            
            // Remove old files if cache is too large
            if totalSize > Design.maxCacheSize {
                oldFiles.sort { $0.1 < $1.1 } // Sort by creation date
                
                for (url, _) in oldFiles.prefix(oldFiles.count / 2) {
                    try? fileManager.removeItem(at: url)
                    print("🗑️ Removed old cached video: \(url.lastPathComponent)")
                }
            }
            
        } catch {
            print("❌ Cache cleanup failed: \(error.localizedDescription)")
        }
    }
    
    private func cleanup() {
        videoLoadTask?.cancel()
        player?.pause()
        
        if let observer = playerObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        player = nil
        playerObserver = nil
        cancellables.removeAll()
        
        print("🧹 ContentViewModel cleanup completed")
    }
}

// MARK: - Video Error Types

enum VideoError: LocalizedError {
    case assetNotFound(String)
    case cachingFailed(Error)
    case playbackFailed
    case loadTimeout
    
    var errorDescription: String? {
        switch self {
        case .assetNotFound(let name):
            return "Video asset '\(name)' not found in bundle"
        case .cachingFailed(let error):
            return "Failed to cache video: \(error.localizedDescription)"
        case .playbackFailed:
            return "Video playback failed"
        case .loadTimeout:
            return "Video loading timed out"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .assetNotFound:
            return "Please ensure the video file is included in the app bundle"
        case .cachingFailed:
            return "Check available storage space and try again"
        case .playbackFailed:
            return "Try restarting the app or check your device capabilities"
        case .loadTimeout:
            return "Check your network connection and try again"
        }
    }
}

// MARK: - Navigation Extensions

extension ContentViewModel {
    
    /// Handle deep link navigation
    func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let path = components.path.components(separatedBy: "/").last else {
            return
        }
        
        switch path {
        case "login":
            navigateToLogin()
        case "signup":
            navigateToSignup()
        default:
            print("⚠️ Unknown deep link path: \(path)")
        }
    }
    
    /// Reset navigation state
    func resetNavigation() {
        showLoginView = false
        showSignupView = false
    }
}

// MARK: - Analytics Extensions

extension ContentViewModel {
    
    /// Track user interaction
    func trackUserInteraction(_ action: String) {
        // In a real app, this would send analytics data
        print("📊 User interaction tracked: \(action)")
    }
    
    /// Get video performance metrics
    var videoPerformanceMetrics: (isLoaded: Bool, hasError: Bool, isPlaying: Bool) {
        return (
            isLoaded: player != nil,
            hasError: hasVideoError,
            isPlaying: isVideoPlaying
        )
    }
}
