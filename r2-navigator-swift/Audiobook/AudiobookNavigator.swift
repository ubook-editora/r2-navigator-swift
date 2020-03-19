//
//  AudiobookNavigator.swift
//  r2-navigator-swift
//
//  Created by Mickaël Menu on 12/03/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import AVFoundation
import Foundation
import R2Shared

public protocol AudiobookNavigatorDelegate: MediaNavigatorDelegate { }

@available(iOS 10.0, *)
open class AudiobookNavigator: MediaNavigator, Loggable {
    
    public weak var delegate: AudiobookNavigatorDelegate?
    
    private let publication: Publication
    private let initialLocation: Locator?

    public init(publication: Publication, initialLocation: Locator? = nil) {
        self.publication = publication
        self.initialLocation = initialLocation
            ?? publication.readingOrder.first.map { Locator(link: $0) }
    }
    
    // Current playback info.
    public var playbackInfo: MediaPlaybackInfo {
        MediaPlaybackInfo(
            resourceIndex: resourceIndex,
            state: state,
            time: currentTime,
            duration: duration
        )
    }
    
    // Index of the current resource in the reading order.
    private var resourceIndex: Int = 0
    
    /// Duration in seconds in the current resource.
    private var duration: Double? {
        if let duration = player.currentItem?.duration, duration.isNumeric {
            return duration.secondsOrZero
        } else {
            return publication.readingOrder[resourceIndex].duration
        }
    }
    
    private var timeControlStatusObserver: NSKeyValueObservation?
    private var currentItemObserver: NSKeyValueObservation?

    private lazy var player: AVPlayer = {
        let player = AVPlayer()
        player.allowsExternalPlayback = false
        
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 1000), queue: .main) { [weak self] time in
            if let self = self {
                let time = time.secondsOrZero
                self.delegate?.navigator(self, locationDidChange: self.makeLocator(forTime: time))
                self.playbackDidChange(time)
            }
        }
        
        timeControlStatusObserver = player.observe(\.timeControlStatus, options: [.new, .old]) { [weak self] player, change in
            self?.playbackDidChange()
        }
        
        currentItemObserver = player.observe(\.currentItem, options: [.new, .old]) { [weak self] player, change in
            self?.playbackDidChange()
        }

        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] notification in
            if let self = self,
                (self.delegate?.navigator(self, shouldPlayNextResource: self.makePlaybackInfo()) ?? true),
                let currentItem = player.currentItem,
                currentItem == (notification.object as? AVPlayerItem) {
                if self.goToNextResource() {
                    self.play()
                }
            }
        }
        
        return player
    }()
    
    private func playbackDidChange(_ time: Double? = nil) {
        delegate?.navigator(self, playbackDidChange: makePlaybackInfo(forTime: time))
        // FIXME: probably not working when paused
        delegate?.navigator(self, loadedTimeRangesDidChange: (player.currentItem?.loadedTimeRanges ?? [])
            .map { value in
                let range = value.timeRangeValue
                let start = range.start.secondsOrZero
                let duration = range.duration.secondsOrZero
                return start..<(start + duration)
            }
        )
    }
    
    private func makePlaybackInfo(forTime time: Double? = nil) -> MediaPlaybackInfo {
        return MediaPlaybackInfo(
            resourceIndex: resourceIndex,
            state: state,
            time: time ?? currentTime,
            duration: duration
        )
    }

    private func makeLocator(forTime time: Double) -> Locator {
        let link = publication.readingOrder[resourceIndex]
        return Locator(
            href: link.href,
            type: link.type ?? "audio/*",
            title: link.title,
            locations: Locations(
                fragments: ["t=\(time)"],
                progression: duration.map { time / $0 },
                // FIXME: totalProgression
                totalProgression: nil
            )
        )
    }

    // MARK: - Navigator
    
    public var currentLocation: Locator? {
        makeLocator(forTime: currentTime)
    }
    
    @discardableResult
    public func go(to locator: Locator, animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        guard let newResourceIndex = publication.readingOrder.firstIndex(withHref: locator.href),
            let url = URL(string: locator.href, relativeTo: publication.baseURL) else {
            return false
        }
        
        player.pause()
        
        // Loads resource
        if player.currentItem == nil || resourceIndex != newResourceIndex {
            player.replaceCurrentItem(with: AVPlayerItem(url: url))
            resourceIndex = newResourceIndex
            delegate?.navigator(self, loadedTimeRangesDidChange: [])
        }

        // Seeks to time
        let time = locator.time(forDuration: duration) ?? 0
        if time > 0 {
            player.seek(to: CMTime(seconds: time, preferredTimescale: 1000))
        }
        
        player.play()

        return true
    }


    @discardableResult
    public func go(to link: Link, animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        return go(to: Locator(link: link), animated: animated, completion: completion)
    }
    
    @discardableResult
    public func goForward(animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        return false
    }
    
    @discardableResult
    public func goBackward(animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        return false
    }
    
    @discardableResult
    public func goToNextResource(animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        return goToResourceIndex(resourceIndex + 1, animated: animated, completion: completion)
    }
    
    @discardableResult
    public func goToPreviousResource(animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        return goToResourceIndex(resourceIndex - 1, animated: animated, completion: completion)
    }
    
    @discardableResult
    public func goToResourceIndex(_ index: Int, animated: Bool = false, completion: @escaping () -> Void = {}) -> Bool {
        guard publication.readingOrder.indices ~= index else {
            return false
        }
        return go(to: publication.readingOrder[index], animated: animated, completion: completion)
    }
    
    // MARK: – MediaNavigator
    
    public var currentTime: Double {
        return player.currentTime().secondsOrZero
    }

    public var volume: Double {
        get { Double(player.volume) }
        set {
            assert(0...1 ~= newValue)
            player.volume = Float(newValue)
        }
    }

    public var rate: Double {
        get { Double(player.rate) }
        set {
            assert(newValue >= 0)
            player.rate = Float(newValue)
        }
    }
    
    public var state: MediaPlaybackState {
        MediaPlaybackState(player.timeControlStatus)
    }

    public func play() {
        if player.currentItem == nil, let location = initialLocation {
            go(to: location)
        }
        
        player.play()
    }

    public func pause() {
        player.pause()
    }
    
    public func seek(to time: Double) {
        player.seek(to: CMTime(seconds: time, preferredTimescale: 1000))
    }
    
    public func seek(relatively delta: Double) {
        seek(to: currentTime + delta)
    }
    
}

private extension Locator {
    
    private static let timeFragmentRegex = try! NSRegularExpression(pattern: #"t=(\d+(?:\.\d+)?)"#)
    
    // FIXME: Should probably be in `Locator` itself.
    func time(forDuration duration: Double? = nil) -> Double? {
        if let progression = locations.progression, let duration = duration {
            return progression * duration
        } else {
            for fragment in locations.fragments {
                let range = NSRange(fragment.startIndex..<fragment.endIndex, in: fragment)
                if let match = Self.timeFragmentRegex.firstMatch(in: fragment, range: range) {
                    let matchRange = match.range(at: 1)
                    if matchRange.location != NSNotFound, let range = Range(matchRange, in: fragment) {
                        return Double(fragment[range])
                    }
                }
            }
        }
        return nil
    }
    
}

@available(iOS 10.0, *)
private extension MediaPlaybackState {
    
    init(_ timeControlStatus: AVPlayer.TimeControlStatus) {
        switch timeControlStatus {
        case .paused:
            self = .paused
        case .waitingToPlayAtSpecifiedRate:
            self = .loading
        case .playing:
            self = .playing
        @unknown default:
            self = .loading
        }
    }
    
}

private extension CMTime {
    
    var secondsOrZero: Double {
        return isNumeric ? seconds : 0
    }
    
}
