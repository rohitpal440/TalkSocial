//
//  TabBarViewController.swift
//  TalkSocial
//
//  Created by Rohit Pal on 26/02/24.
//

import UIKit

class TabBarViewController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let homeViewController = ViewControllerFactory.getFeedHome()
        let profileViewController = ViewControllerFactory.getProfile()
        homeViewController.tabBarItem = UITabBarItem(title: "Home", image: UIImage(named: "home"), selectedImage: UIImage(named: "home_filled"))
        profileViewController.tabBarItem = UITabBarItem(title: "Profile", image: UIImage(named: "profile"), selectedImage: UIImage(named: "profile_filled"))
        
        let controllers = [homeViewController, profileViewController]
        viewControllers = controllers.map { UINavigationController(rootViewController: $0) }
        tabBar.barStyle = .default
        tabBar.isTranslucent = true
    }

}

