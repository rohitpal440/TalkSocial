//
//  FeedViewModel.swift
//  TalkSocial
//
//  Created by Rohit Pal on 05/03/24.
//

import Foundation
import RealmSwift


protocol FeedViewModel: AnyObject {
    
    var onLoad: (() -> Void)? { get set }
    var onReloadRowsUpdate: ((_ indexPaths: [IndexPath]) -> Void)? { get set }
    var onError: ((_ errorMessage: String) -> Void)? { get set }
    var updateLoaderVisibility: ((_ visible: Bool) -> Void)? { get set }
    var showNoDataState: (() -> Void)? { get set }
    var refreshControlVisibilityUpdate: ((_ visible: Bool) -> Void)? { get set }
    var navigateToPostDetail: ((String) -> Void)? { get set }
    
    func viewLoaded()
    func didTapLikeButton(onPostId: String)
    func didSelectItem(atIndexPath: IndexPath)
    func didReachAtEnd()
    func didExecutePullToRefresh()
    
    func canLoadMoreFeed() -> Bool
    func getNumberSection() -> Int
    func getNumberOfRows(inSection section: Int) -> Int
    func getFeedPostModel(atIndexPath indexPath: IndexPath) -> FeedPostViewModelData?

}

class FeedViewModelImpl: FeedViewModel {
    var refreshControlVisibilityUpdate: ((Bool) -> Void)?
    
    var onReloadRowsUpdate: ((_ indexPaths: [IndexPath]) -> Void)?
    
    var updateLoaderVisibility: ((Bool) -> Void)?
    
    var onLoad: (() -> Void)?
    
    var onUpdateLiked: ((Bool) -> Void)?
    
    var onError: ((String) -> Void)?
    
    var showNoDataState: (() -> Void)?
    
    var navigateToPostDetail: ((String) -> Void)?
    
    private let service: FeedService
    private var fetchedFeeds: [FeedPostViewModelData] = []
    
    init(service: FeedService) {
        self.service = service
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
    
    func canLoadMoreFeed() -> Bool {
        return fetchedFeeds.isEmpty || service.canFetchUpcomingFeeds
    }
    
    func didSelectItem(atIndexPath indexPath: IndexPath) {
        guard indexPath.section == 0, indexPath.row < fetchedFeeds.count else { return }
        let postId = fetchedFeeds[indexPath.row].postId
        self.navigateToPostDetail?(postId)
    }
    
    func didTapLikeButton(onPostId postId: String) {
        guard let index = fetchedFeeds.firstIndex(where: { $0.postId == postId }) else {
            return
        }
        var post = fetchedFeeds[index]
        post.likeCount = max(0, (post.likeCount ?? 0) + (post.isLiked == true ? -1 : 1))
        fetchedFeeds[index] = post
        onReloadRowsUpdate?([.init(row: index, section: 0)])
    }
    
    func didReachAtEnd() {
        guard service.canFetchOlderFeeds else {
            return
        }
        service.loadOlderFeeds {[weak self] result in
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
        service.refreshFeeds {[weak self] result in
            var loadedModel: [FeedPostViewModelData]?
            switch result {
            case .success(let models):
                loadedModel = models.toFeedPostViewModelData()
            case .failure(let error):
                self?.onError?(error.getMessage())
            }
            
            DispatchQueue.main.async {
                guard let models = loadedModel else { return }
                self?.updateData(withModels: loadedModel ?? [])
            }
            self?.refreshControlVisibilityUpdate?(false)
        }
    }
    
    private func loadData() {
        updateLoaderVisibility?(true)
        service.loadFeed {[weak self] result in
            let loadedModels = result.toFeedPostViewModelData()
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

