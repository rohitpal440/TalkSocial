//
//  LoadingViewCell.swift
//  TalkSocial
//
//  Created by Rohit Pal on 05/03/24.
//

import UIKit

class LoadingViewCell: UITableViewCell {
    
    @IBOutlet private weak var containerView: UIView!
    private var activityIndicator: UIActivityIndicatorView?
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        DispatchQueue.main.async {[weak self] in
            self?.showLoading()
        }
    }
    
    
    func getActivityIndicator() -> UIActivityIndicatorView {
        guard let activityIndicator else {
            let indicator = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.medium)
            indicator.hidesWhenStopped = true
            indicator.center = self.containerView.center
            self.containerView.addSubview(indicator)
            activityIndicator = indicator
            return indicator
        }
        return activityIndicator
    }
    
    
    private func showLoading() {
        getActivityIndicator().startAnimating()
    }
    
    private func hideLoading() {
        activityIndicator?.stopAnimating()
        activityIndicator?.removeFromSuperview()
        activityIndicator = nil
    }
    
}
