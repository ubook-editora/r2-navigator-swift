//
//  MediaNavigator.swift
//  r2-navigator-swift
//
//  Created by Mickaël Menu on 12/03/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

public enum MediaNavigatorState {
    case paused
    case loading
    case playing
}

public protocol MediaNavigator: Navigator {
    
    /// Current playback position in seconds.
    var currentTime: Double { get }
    
    /// Volume of playback, from 0.0 to 1.0.
    var volume: Double { get set }
    
    /// Speed of playback.
    /// Default is 1.0
    var rate: Double { get set }

    /// Returns whether the media is currently playing or not.
    var state: MediaNavigatorState { get }

    /// Resumes or start the playback.
    func play()
    
    /// Pauses the playback.
    func pause()
    
}

extension MediaNavigator {
    
    /// Toggles the playback.
    func togglePlayback() {
        switch state {
        case .loading, .playing:
            pause()
        case .paused:
            play()
        }
    }
    
}

public protocol MediaNavigatorDelegate: NavigatorDelegate {
    
    /// Called when the playback status changes.
    func navigator(_ navigator: MediaNavigator, stateDidChange state: MediaNavigatorState)
    
    /// Called when the duration or current time changes.
    func navigator(_ navigator: MediaNavigator, timeDidChange time: Double, duration: Double?)
    
    /// Called when the loaded audio data ranges change.
    func navigator(_ navigator: MediaNavigator, loadedTimeRangesDidChange ranges: [Range<Double>])
    
}

public extension MediaNavigatorDelegate {
    
    func navigator(_ navigator: MediaNavigator, stateDidChange state: MediaNavigatorState) {
        // Optional
    }
    
    func navigator(_ navigator: MediaNavigator, timeDidChange time: Double, duration: Double?) {
        // Optional
    }
    
    func navigator(_ navigator: MediaNavigator, loadedTimeRangesDidChange ranges: [Range<Double>]) {
        // Optional
    }
    
}
