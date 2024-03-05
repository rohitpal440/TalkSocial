//
//  UserPostsCell.swift
//  TalkSocial
//
//  Created by Rohit Pal on 02/03/24.
//

import UIKit

class UserPostsCell: UICollectionViewCell {
    @IBOutlet weak var thumbnailImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    
    func setup(viewModel: FeedPostViewModelData) {
        thumbnailImageView.pin_setImage(from: URL(string: viewModel.thumbnailUrl ?? ""), placeholderImage: UIImage(named: "video_circle"))
    }
}
