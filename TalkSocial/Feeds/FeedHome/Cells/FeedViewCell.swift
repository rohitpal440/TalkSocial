//
//  FeedViewCell.swift
//  TalkSocial
//
//  Created by Rohit Pal on 27/02/24.
//

import UIKit
import AVFoundation
import PINRemoteImage

struct CommentViewModelData {
    let userName: String
    let profileImageUrl: String?
    let messasge: String
    let postID: String?
    let commentId: String
    let parentCommentId: String?
}

struct FeedPostViewModelData {
    let postId: String
    let userName: String
    let profileImageUrl: String?
    var likeCount: Int?
    let commentCount: Int = Int.random(in: 10...100)
    let caption: String?
    let topComments: [CommentViewModelData]?
    let videoUrl: String?
    let thumbnailUrl: String?
    let time: Date?
    var isLiked: Bool?
    lazy var asset: VividAsset? = {
        guard let urlStr = self.videoUrl,
              let url = URL(string: urlStr) else { return  nil }
        let asset = VividAsset(url: url)
        return asset
    }()
}



class FeedViewCell: UITableViewCell {
    @IBOutlet private weak var videoPlayerView: VideoView!
    @IBOutlet private weak var thumbnailImageView: UIImageView!
    
    @IBOutlet private weak var shareButton: UIControl!
    @IBOutlet private weak var commentCountLabel: UILabel!
    @IBOutlet private weak var commentButton: UIControl!
    
    @IBOutlet private weak var LikeButton: UIControl!
    @IBOutlet private weak var likeCountLabel: UILabel!
    
    @IBOutlet private weak var profileImageVIew: UIImageView!
    @IBOutlet private weak var userNameLabel: UILabel!
    @IBOutlet private weak var timeStampLabel: UILabel!
    
    @IBOutlet private weak var commentContainer: UIStackView!
    
    @IBOutlet private weak var commentProfileImageView: UIImageView!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        userNameLabel.text = ""
        userNameLabel.font = .boldSystemFont(ofSize: 14)
        LikeButton.sendSubviewToBack(LikeButton.addBlurEffect(style: .regular))
    }
    
    func applyShadows() {
        [commentButton, shareButton, userNameLabel, timeStampLabel].forEach { $0?.layer.applyShadow() }
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
        commentProfileImageView.pin_setImage(from: URL(string: model.profileImageUrl ?? ""), placeholderImage: UIImage(named: "profile_filled"))
        likeCountLabel.set(text: model.likeCount != nil ? model.likeCount?.asFormattedString : "", hideOnEmpty: true)
        commentCountLabel.set(text: model.commentCount.asFormattedString, hideOnEmpty: true)
        populateCaptionAndComments(model: model)
        if let videoUrl = model.videoUrl,
            let url = URL(string: videoUrl) {
            var model = model
            if let asset = model.asset  {
                videoPlayerView.setItem(asset, thumbnailUrl: URL(string: model.thumbnailUrl ?? ""))
            } else {
                videoPlayerView.setItem(url, thumbnailUrl: URL(string: model.thumbnailUrl ?? ""))
            }
            
            videoPlayerView.isLoopEnabled = true
            videoPlayerView.videoGravity = .resizeAspectFill

        } else {
            prepareForReuse()
        }
        self.layoutIfNeeded()
        DispatchQueue.main.async {[weak self] in
            self?.applyShadows()
        }
    }
    
    func playMedia() {
        self.videoPlayerView.play()
    }
    
    func pauseMedia() {
        self.videoPlayerView.pause()
    }
    

    private func populateCaptionAndComments(model: FeedPostViewModelData) {
        commentContainer.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let caption = UILabel()
        caption.numberOfLines = 3
        caption.translatesAutoresizingMaskIntoConstraints = false
        caption.set(text: model.caption)
        commentContainer.addArrangedSubview(caption)
        
        let topComments = model.topComments ?? []
        for comment in topComments.prefix(2){
            let imageView = UIImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.widthAnchor.constraint(equalToConstant: 24).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: 24).isActive = true
            
            imageView.layer.masksToBounds = true
            imageView.layer.cornerRadius = 12
            imageView.pin_setImage(from: URL(string: comment.profileImageUrl ?? ""), placeholderImage: UIImage(named: "profile_filled"))
            let commentMessage = UILabel()
            commentMessage.translatesAutoresizingMaskIntoConstraints = false
            commentMessage.set(attributedText: NSMutableAttributedString().bold(comment.userName).normal(" \(comment.messasge)"))
            commentMessage.numberOfLines = 1
            
            let stackView = UIStackView()
            stackView.axis = .horizontal
            stackView.alignment = .center
            stackView.distribution = .fill
            stackView.spacing = 8
            stackView.translatesAutoresizingMaskIntoConstraints = false
            
            
            stackView.addArrangedSubview(imageView)
            stackView.addArrangedSubview(commentMessage)
            
            commentContainer.addArrangedSubview(stackView)
        }
        commentContainer.axis = .vertical
        commentContainer.distribution = .fill
        commentContainer.alignment = .leading
    }

    
    private func preparePlayerForReuse() {
        videoPlayerView.deallocate()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        preparePlayerForReuse()
    }
    
}
