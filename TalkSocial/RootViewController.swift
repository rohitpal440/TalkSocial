//
//  ViewController.swift
//  TalkSocial
//
//  Created by Rohit Pal on 26/02/24.
//

import UIKit
//import ToastViewSwift
import AVFoundation

class RootViewController: UIViewController {
    var service: FeedService?
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        super.viewDidLoad()
                view.backgroundColor = .white
                
                let tabBarViewController = TabBarViewController()
                addChild(tabBarViewController)
                view.addSubview(tabBarViewController.view)
                tabBarViewController.didMove(toParent: self)
    }

}

