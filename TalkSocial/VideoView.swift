//
//  VideoView.swift
//  TalkSocial
//
//  Created by Rohit Pal on 05/03/24.
//

import UIKit
import AVKit
import AVFoundation

class VideoView: UIView {

    private var url: URL?

    var playerLayer: AVPlayerLayer?
    
    private var player: AVPlayer?
    
    private var rate: Float = 1.0
    
    static let status: String = "status"
    private var statusObserver: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?
    private var emptyBufferObserver: NSKeyValueObservation?
    private var stallPlaybackObserver: NSKeyValueObservation?
    var isLoopEnabled: Bool = true
    private var activityIndicator: UIActivityIndicatorView?
    var thumbnailView: UIImageView?
    var videoGravity: AVLayerVideoGravity = .resizeAspect {
        didSet {
            self.playerLayer?.videoGravity = videoGravity
        }
    }
    
    var isMuted: Bool = false {
        didSet {
            player?.isMuted = self.isMuted
        }
    }
    
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        didLoad()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        didLoad()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
    
    func didLoad() {
        frame = bounds
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backgroundColor = .clear
        clipsToBounds = true
        layer.masksToBounds = false
        
        player = AVPlayer()
        player?.allowsExternalPlayback = false
        player?.rate = 1.0
        player?.isMuted = self.isMuted
        

        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = bounds
        playerLayer?.videoGravity = videoGravity
        // Add the AVPlayerLayer to this view's layer
        layer.addSublayer(playerLayer!)
        
        let imageView = getThumnailView()
        self.thumbnailView = imageView
        self.addSubview(imageView)
        imageView.isHidden = true
        addObservers()
        
        // Layout the subviews
        layoutSubviews()
    }
    
    func getThumnailView () -> UIImageView {
        let imageView = UIImageView(frame: self.bounds)
        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = .clear
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return imageView
    }
    
    func getActivityIndicator() -> UIActivityIndicatorView {
        guard let activityIndicator else {
            let indicator = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.medium)
            indicator.hidesWhenStopped = true
            indicator.center = self.center
            self.addSubview(indicator)
            activityIndicator = indicator
            self.bringSubviewToFront(indicator)
            return indicator
        }
        return activityIndicator
    }
    
    
    func showLoading() {
        getActivityIndicator().startAnimating()
    }
    
    func hideLoading() {
        self.thumbnailView?.isHidden = true
        activityIndicator?.stopAnimating()
        activityIndicator?.removeFromSuperview()
        activityIndicator = nil
    }
    
    deinit {
        removeObservers()
        playerLayer = nil
        player = nil
    }
    
    /// Removes all KVO and NotificationCenter observers.
    func removeObservers() {
        // Remove observers
        player?.removeObserver(self, forKeyPath: VideoView.status)
        emptyBufferObserver = nil
        statusObserver = nil
        stallPlaybackObserver = nil
        timeControlObserver = nil
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
    }
    
    /// Adds all the associated KVO and NotificationCenter observers.
    func addObservers() {
        player?.addObserver(self, forKeyPath: VideoView.status, options: [], context: nil)
        
        // listening for current item status change
         statusObserver = player?.currentItem?.observe(\.status, options:  [.new, .old], changeHandler: {
            (playerItem, change) in
            if playerItem.status == .readyToPlay {
                print("current item status is ready")
            }
        })

        // listening for buffer is empty
        emptyBufferObserver = player?.currentItem?.observe(\.isPlaybackBufferEmpty, options: [.new]) {
            [weak self] (_, _) in
            self?.showLoading()
        }
        // listening for event that buffer is almost full
        stallPlaybackObserver = player?.currentItem?.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) {
            [weak self] (_, _) in
            self?.hideLoading()
        }


        // listening for event about the status of the playback
        timeControlObserver = player?.observe(\.timeControlStatus, options: [.new, .old], changeHandler: {[weak self]
            (playerItem, change) in
            switch (playerItem.timeControlStatus) {
            case .paused:
                print("Media Paused")
                self?.hideLoading()
            case .playing:
                self?.hideLoading()
            case .waitingToPlayAtSpecifiedRate:
                self?.showLoading()
                print("Media Waiting to play at specific rate!")
            @unknown default:
                print("unhandled status")
            }
        })

        
        // MARK: - NotificationCenter
        NotificationCenter.default.addObserver(self, selector: #selector(videoDidEnd(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player?.currentItem)
    }
    
    /// NOTE: Make sure to call this method if you want the video to stop playing between queues (ie: when multiple videos are preloaded in collecton view cells and you want the previous video to stop playing). Generally this method is suitable for a cell's 'prepareForReuse()' method.
    func deallocate() {
        // MARK: - AVPlayer
        player?.pause()
        player?.replaceCurrentItem(with: nil)
    }
    
    /// Set the video for this view using
    /// - Parameter url: The URL path (whether remote or local) of the video content.
    func setItem(_ url: URL, thumbnailUrl: URL?) {
        // Remove the observers
        removeObservers()
        
        // MARK: - AVPlayer
        player = AVPlayer(url: url)
        setup()
    }
    
    func setItem(_ asset: AVURLAsset, thumbnailUrl: URL?) {
        removeObservers()
        self.thumbnailView?.pin_setImage(from: thumbnailUrl)
        self.thumbnailView?.isHidden = false
        let playerItem = AVPlayerItem(asset: asset)
        if let player  {
            player.replaceCurrentItem(with: playerItem)
        } else {
            self.player = AVPlayer(playerItem: playerItem)
        }
        player?.rate = 1.0
        player?.pause()
        setup()
    }
    
    private func setup() {
        player?.allowsExternalPlayback = false
        player?.isMuted = self.isMuted
        
        // MARK: - AVPlayerLayer
        if playerLayer == nil{
            playerLayer = AVPlayerLayer(player: player)
            playerLayer?.frame = bounds
            playerLayer?.videoGravity = videoGravity
        }
        if playerLayer?.superlayer != layer {
            // Add the AVPlayerLayer to this view's layer
            layer.addSublayer(playerLayer!)
        }
        showLoading()
        addObservers()
    }
    
    func play(rate: Float = 1.0) {
        // Set the rate
        self.rate = rate
        
        
        guard player?.timeControlStatus != .playing else {
            print("\(#file) \(#function) - Exiting method because the video is currently NOT playing.")
            return
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
        } catch let error {
            print("\(#file) \(#function) - Error enabling background audio to play continuously with movie playback \(error.localizedDescription)")
        }
        self.player?.playImmediately(atRate: rate)
    }
    
    func pause() {
        player?.pause()
    }

    @objc func videoDidEnd(_ sender: Notification) {
        // Execute the following if 'isLoopEnabled' is TRUE
        guard isLoopEnabled == true else {
            print("\(#file) \(#function) - Exiting method because 'isLoopEnabled' is FALSE.")
            return
        }
        
        player?.pause()
        player?.seek(to: CMTime.zero)
        player?.play()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        // Unwrap the object to ensure that it is indeed an AVPlayer
        guard let playerObject = object as? AVPlayer else {
            print("\(#file) \(#function) - Exiting method because the object is NOT an AVPlayer.")
            return
        }
        
        // Ensure that the AVPlayer object is this class' AVPlayer object and that the 'keyPath' value is "status"
        guard playerObject == self.player && keyPath == VideoView.status else {
            print("\(#file) \(#function) - Exiting method because the AVPlayer doesn't reference self and its 'keyPath' is NOT \"status\".")
            return
        }
        print(change)
        guard let status = self.player?.currentItem?.status else { return }
        switch status {
        case .unknown, .failed:
            break
        case .readyToPlay:
            hideLoading()
        @unknown default:
            break
        }
        
    }
}
