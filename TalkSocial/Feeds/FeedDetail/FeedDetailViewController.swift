//
//  FeedDetailViewController.swift
//  TalkSocial
//
//  Created by Rohit Pal on 02/03/24.
//

import UIKit
import AVFoundation

class FeedDetailViewController: UIViewController {
    @IBOutlet private weak var videoPlayerView: VideoView!
    @IBOutlet private weak var thumbnailImageView: UIImageView!
    
    @IBOutlet weak var shareButton: UIControl!
    @IBOutlet private weak var commentCountLabel: UILabel!
    @IBOutlet private weak var commentButton: UIControl!
    
    @IBOutlet private weak var LikeButton: UIControl!
    @IBOutlet private weak var likeCountLabel: UILabel!
    
    @IBOutlet private weak var profileImageVIew: UIImageView!
    @IBOutlet private weak var userNameLabel: UILabel!
    @IBOutlet private weak var timeStampLabel: UILabel!
    
    @IBOutlet private weak var commentContainer: UIStackView!

    @IBOutlet private weak var captionLabel: ExpandableLabel!
    private var activityIndicator: UIActivityIndicatorView?
    
    @IBOutlet weak var errorContainer: UIView!
    @IBOutlet weak var retryButton: UIButton!
    @IBOutlet weak var errorLabel: UILabel!

    var viewModel: FeedDetailViewModel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        // Do any additional setup after loading the view.
        userNameLabel.text = ""
        userNameLabel.font = .boldSystemFont(ofSize: 14)
        LikeButton.sendSubviewToBack(LikeButton.addBlurEffect(style: .regular))
        subscribeObservable()
        viewModel?.viewLoaded()
    }
    
    func applyShadows() {
        [commentButton, shareButton, userNameLabel, timeStampLabel].forEach { $0?.layer.applyShadow() }
    }
    
    
    @IBAction func didTapRetry(_ sender: Any) {
        viewModel?.retryLoad()
    }
    
    @IBAction func didTapBackButton(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    
    private func subscribeObservable() {
        viewModel?.onLoad =  {[weak self] postData in
            DispatchQueue.main.async {
                self?.setupWith(model: postData)
                self?.errorContainer.isHidden = true
                self?.applyShadows()
            }
        }
        
        viewModel?.showNoDataState =  {[weak self] in
            DispatchQueue.main.async {
                self?.errorLabel.text = "Looks like there is not display!"
                self?.errorContainer.isHidden = false
            }
        }
        
        viewModel?.onError = {[weak self] message in
            DispatchQueue.main.async {
                
                self?.errorLabel.text = message
                self?.errorContainer.isHidden = false
            }
        }
        
        viewModel?.updateLoaderVisibility = {[weak self] visible in
            DispatchQueue.main.async {
                visible ? self?.showLoading() : self?.hideLoading()
            }
        }
        
        
        viewModel?.onUpdateLiked = {[weak self] isLiked in
            DispatchQueue.main.async {
                self?.LikeButton.backgroundColor = isLiked ? .red : .clear
            }
        }
    }
    
    func getActivityIndicator() -> UIActivityIndicatorView {
        guard let activityIndicator else {
            let indicator = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.medium)
            indicator.hidesWhenStopped = true
            indicator.center = self.view.center
            self.view.addSubview(indicator)
            activityIndicator = indicator
            return indicator
        }
        return activityIndicator
    }
    
    
    func showLoading() {
        getActivityIndicator().startAnimating()
    }
    
    func hideLoading() {
        activityIndicator?.stopAnimating()
        activityIndicator?.removeFromSuperview()
        activityIndicator = nil
    }
    
    func setupWith(model: FeedPostViewModelData) {
        userNameLabel.text = model.userName
        if let date = model.time {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            dateFormatter.doesRelativeDateFormatting = true
            timeStampLabel.text = dateFormatter.string(from: date)
        }
        profileImageVIew.pin_setImage(from: URL(string: model.profileImageUrl ?? ""), placeholderImage: UIImage(named: "profile_filled"))
        likeCountLabel.set(text: model.likeCount != nil ? model.likeCount?.asFormattedString : "", hideOnEmpty: true)
        commentCountLabel.set(text: model.commentCount.asFormattedString, hideOnEmpty: true)
        captionLabel.set(text: model.caption)
        if let videoUrl = model.videoUrl,
            let url = URL(string: videoUrl) {
            var model = model
            if var asset = model.asset {
                videoPlayerView.setItem(asset, thumbnailUrl: URL(string: model.thumbnailUrl ?? ""))
            } else {
                videoPlayerView.setItem(url, thumbnailUrl: URL(string: model.thumbnailUrl ?? ""))
            }
            
            videoPlayerView.isLoopEnabled = true
            videoPlayerView.playerLayer?.videoGravity = .resizeAspectFill
            videoPlayerView.play()
        }
        self.view.layoutIfNeeded()
    }
}
