//
//  FeedDetailViewModel.swift
//  TalkSocial
//
//  Created by Rohit Pal on 05/03/24.
//

import Foundation

protocol FeedDetailViewModel {
    var onLoad: ((_ modelData: FeedPostViewModelData) -> Void)? { get set }
    var onUpdateLiked: ((_ isLiked: Bool) -> Void)? { get set }
    var showNoDataState: (() -> Void)? { get set }
    var onError: ((String) -> Void)? { get set }
    var updateLoaderVisibility: ((Bool) -> Void)? { get set }
    
    func didTapLikeButton()
    func viewLoaded()
    func retryLoad()
}

class FeedDetailViewModelImpl: FeedDetailViewModel {
    var onLoad: ((FeedPostViewModelData) -> Void)?
    
    var onUpdateLiked: ((Bool) -> Void)?
    
    var showNoDataState: (() -> Void)?
    
    var onError: ((String) -> Void)?
    
    var updateLoaderVisibility: ((Bool) -> Void)?
    
    private var postId: String
    
    private var modelData: FeedPostViewModelData?
    private var feedPostService: FeedPostService
    
    init(postId: String, service: FeedPostService) {
        self.postId = postId
        self.feedPostService = service
    }
    
    
    func viewLoaded() {
        loadPost()
    }
    
    func didTapLikeButton() {
        modelData?.isLiked = modelData?.isLiked == true ? false : true
        onUpdateLiked?( modelData?.isLiked == true)
    }
    
    func retryLoad() {
        loadPost()
    }
            

    func loadPost() {
        updateLoaderVisibility?(true)
        feedPostService.loadPost(id: postId) {[weak self] result in
            var fetchedData: FeedPostViewModelData?
            switch result {
            case .success(let model):
                fetchedData = [model].toFeedPostViewModelData()[0]
            case .failure(let error):
                self?.onError?(error.getMessage())
            }
            DispatchQueue.main.async {
                if let fetchedData {
                    self?.modelData = fetchedData
                    self?.onLoad?(fetchedData)
                }
                self?.updateLoaderVisibility?(false)
            }
        }
    }
}


