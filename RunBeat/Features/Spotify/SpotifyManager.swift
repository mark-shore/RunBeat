//
//  SpotifyManager.swift
//  RunBeat
//
//  COMPATIBILITY WRAPPER - delegates to SpotifyViewModel for new MVVM architecture
//  Will be phased out once all components are updated to use SpotifyViewModel directly
//

import Foundation
import SpotifyiOS
import UIKit
import Combine

class SpotifyManager: NSObject, ObservableObject {
    static let shared = SpotifyManager()
    
    // Published properties forwarded from ViewModel
    @Published var isConnected = false
    @Published var currentTrack: String = ""
    @Published var isPlaying = false
    
    // MVVM Architecture - delegate to ViewModel
    private let viewModel: SpotifyViewModel
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        self.viewModel = SpotifyViewModel.shared
        super.init()
        setupViewModelBinding()
    }
    
    private func setupViewModelBinding() {
        // Bind ViewModel published properties to this manager's published properties
        viewModel.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: \.isConnected, on: self)
            .store(in: &cancellables)
            
        viewModel.$currentTrack
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentTrack, on: self)
            .store(in: &cancellables)
            
        viewModel.$isPlaying
            .receive(on: DispatchQueue.main)
            .assign(to: \.isPlaying, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Compatibility API - delegates to ViewModel
    
    func connect() {
        viewModel.connect()
    }
    
    func handleCallback(url: URL) {
        viewModel.handleCallback(url: url)
    }
    
    func disconnect() {
        viewModel.disconnect()
    }
    
    func reconnect() {
        viewModel.reconnect()
    }
    
    func activateDeviceForTraining(playlistID: String? = nil, completion: @escaping (Bool) -> Void) {
        viewModel.activateDeviceForTraining(completion: completion)
    }
    
    func resetDeviceActivationState() {
        viewModel.resetDeviceActivationState()
    }
    
    func playHighIntensityPlaylist() {
        viewModel.playHighIntensityPlaylist()
    }
    
    func playRestPlaylist() {
        viewModel.playRestPlaylist()
    }
    
    func pause() {
        viewModel.pause()
    }
    
    func resume() {
        viewModel.resume()
    }
}

// MARK: - Deprecated Methods 
// These methods are kept for compatibility but should be migrated to use ViewModel directly
extension SpotifyManager {
    @available(*, deprecated, message: "Use SpotifyViewModel directly instead")
    func resetConnectionState() {
        // No-op for compatibility
    }
    
    @available(*, deprecated, message: "Use SpotifyViewModel directly instead") 
    func skipNext() {
        // No-op for compatibility - implement if needed
    }
    
    @available(*, deprecated, message: "Use SpotifyViewModel directly instead")
    func skipPrevious() {
        // No-op for compatibility - implement if needed  
    }
}