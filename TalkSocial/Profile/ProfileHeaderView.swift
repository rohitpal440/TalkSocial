//
//  ProfileHeaderView.swift
//  TalkSocial
//
//  Created by Rohit Pal on 02/03/24.
//

import UIKit

class ProfileHeaderView: UICollectionReusableView {
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var profileImageView: UIImageView!
    
    @IBOutlet weak var bioLabel: UILabel!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    func setup(userName: String, about: String?, profiePicUrl: String?) {
        profileImageView.pin_setImage(from: URL(string: profiePicUrl ?? ""), placeholderImage: UIImage(named: "profile_filled"))
        userNameLabel.attributedText = NSMutableAttributedString(string: "").bold(userName)
        bioLabel.set(text: about)
    }
    
}
