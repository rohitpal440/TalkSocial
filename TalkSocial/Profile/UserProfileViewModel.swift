//
//  UserProfileViewModel.swift
//  TalkSocial
//
//  Created by Rohit Pal on 05/03/24.
//

import Foundation

protocol UserProfileViewModel: AnyObject {
    var onLoad: (() -> Void)? { get set }
    var onError: ((_ errorMessage: String) -> Void)? { get set }
    var updateLoaderVisibility: ((_ visible: Bool) -> Void)? { get set }
    var showNoDataState: (() -> Void)? { get set }
    var refreshControlVisibilityUpdate: ((_ visible: Bool) -> Void)? { get set }
    var navigateToPostDetail: ((String) -> Void)? { get set }
    
    func viewLoaded()
    func didSelectItem(atIndexPath: IndexPath)
    func didReachAtEnd()
    func didExecutePullToRefresh()
    
    func canLoadMorePost() -> Bool
    func hasNotPostedAnything() -> Bool
    func getNumberSection() -> Int
    func getNumberOfRows(inSection section: Int) -> Int
    func getFeedPostModel(atIndexPath indexPath: IndexPath) -> FeedPostViewModelData?
    func getHeaderModel(atSection section: Int) -> (userName: String, about: String?, profilePicUrl: String?)?
    
}

class UserProfileViewModelImpl: UserProfileViewModel {
    var onLoad: (() -> Void)?
    
    var refreshControlVisibilityUpdate: ((Bool) -> Void)?
    
    var onReloadRowsUpdate: ((_ indexPaths: [IndexPath]) -> Void)?
    
    var updateLoaderVisibility: ((Bool) -> Void)?

    
    var onUpdateLiked: ((Bool) -> Void)?
    
    var onError: ((String) -> Void)?
    
    var showNoDataState: (() -> Void)?
    
    var navigateToPostDetail: ((String) -> Void)?
    
    private let service: ProfileService
    private var fetchedFeeds: [FeedPostViewModelData] = []
    
    init(service: ProfileService) {
        self.service = service
    }
    
    func hasNotPostedAnything() -> Bool {
        service.hasNotPostedAnything == true
    }
    
    func viewLoaded() {
        // add logic to fetch and populate data
        loadData()
    }

    func getNumberSection() -> Int {
        return 1
    }
    
    func getNumberOfRows(inSection section: Int) -> Int {
        guard section == 0 else { return 0}
        return fetchedFeeds.count
    }
    
    func getFeedPostModel(atIndexPath indexPath: IndexPath) -> FeedPostViewModelData? {
        guard indexPath.section == 0, indexPath.row < fetchedFeeds.count else {
            return nil
        }
        return fetchedFeeds[indexPath.row]
    }
    
    func getHeaderModel(atSection section: Int) -> (userName: String, about: String?, profilePicUrl: String?)? {
        guard section == 0 else { return nil }
        return (service.username, service.about, service.profilePicUrl)
    }
    
    func canLoadMorePost() -> Bool {
        return fetchedFeeds.isEmpty || service.canFetchOlderPosts
    }
    
    func didSelectItem(atIndexPath indexPath: IndexPath) {
        guard indexPath.section == 0, indexPath.row < fetchedFeeds.count else { return }
        let postId = fetchedFeeds[indexPath.row].postId
        self.navigateToPostDetail?(postId)
    }
    
    func didReachAtEnd() {
        guard service.canFetchOlderPosts else {
            return
        }
        service.loadOlderPost {[weak self] result in
            var receivedModels: [FeedPostViewModelData]?
            switch result {
            case .success(let models):
                receivedModels = models.toFeedPostViewModelData()
            case .failure(let error):
                self?.onError?("Failed to load more feeds. " + error.getMessage())
            }
            DispatchQueue.main.async {
                if let receivedModels {
                    self?.fetchedFeeds.append(contentsOf: receivedModels)
                    self?.onLoad?()
                }
            }
        }
    }
    
    func didExecutePullToRefresh() {
        refreshControlVisibilityUpdate?(true)
        service.refreshProfile {[weak self] result in
            var loadedModel: [FeedPostViewModelData]?
            switch result {
            case .success(let models):
                loadedModel = models.posts.toFeedPostViewModelData()
            case .failure(let error):
                self?.onError?(error.getMessage())
            }
            
            DispatchQueue.main.async {
                self?.updateData(withModels: loadedModel ?? [])
            }
            self?.refreshControlVisibilityUpdate?(false)
        }
    }
    
    private func loadData() {
        updateLoaderVisibility?(true)
        service.loadProfile {[weak self] result in
            var loadedModels: [FeedPostViewModelData] = []
            
            switch result {
            case .success(let model):
                loadedModels = model.posts.toFeedPostViewModelData()
            case .failure(let error): break
                
            }
            DispatchQueue.main.async {
                self?.updateData(withModels: loadedModels)
                self?.updateLoaderVisibility?(false)
                self?.didExecutePullToRefresh()
            }
        }
    }
    
    private func updateData(withModels models: [FeedPostViewModelData]) {
        if models.isEmpty {
            self.showNoDataState?()
        }
        self.fetchedFeeds = models
        self.onLoad?()
    }
}
