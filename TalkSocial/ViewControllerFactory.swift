//
//  ViewControllerFactory.swift
//  TalkSocial
//
//  Created by Rohit Pal on 05/03/24.
//

import UIKit

class ViewControllerFactory {
    
    static func getFeedDetail(postId: String) -> UIViewController {
        let viewModel: FeedDetailViewModel = FeedDetailViewModelImpl(postId: postId, service: FeedPostServiceImpl())
        let controller = FeedDetailViewController(nibName: "FeedDetailViewController", bundle: nil)
        controller.viewModel = viewModel
        return controller
    }
    
    static func getFeedHome() -> UIViewController {
        let viewModel: FeedViewModel = FeedViewModelImpl(service: FeedServiceImpl())
        let controller = FeedViewController(nibName: "FeedViewController", bundle: nil)
        controller.viewModel = viewModel
        return controller
    }
    
    
    static func getProfile() -> UIViewController {
        let viewModel = UserProfileViewModelImpl(service: ProfileServiceImpl(username: "Katelyn_Schowalter85"))
        let controller = ProfileViewController(nibName: "ProfileViewController", bundle: nil)
        controller.viewModel = viewModel
        return controller
    }
}
