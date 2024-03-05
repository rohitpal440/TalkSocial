//
//  FeedPostService.swift
//  TalkSocial
//
//  Created by Rohit Pal on 05/03/24.
//

import Foundation
import RealmSwift

protocol FeedPostService: AnyObject {
    
    
    func loadPost(id: String, completion: @escaping (Result<FeedPostModel, CustomError>) -> Void)
    
}

class FeedPostServiceImpl: FeedPostService {
    private var client: WebClient = WebClient.init(baseUrl: "https://api.mocklets.com/p6758/api/post/")
    private let dispatchQueue = DispatchQueue(label: "talk_social_backgroundQueue")
    
    
    func loadPost(id: String, completion: @escaping (Result<FeedPostModel, CustomError>) -> Void) {
        dispatchQueue.async {[weak self] in
            self?._loadPost(id: id, completion: completion)
        }
    }
    
    func _loadPost(id: String, completion: @escaping (Result<FeedPostModel, CustomError>) -> Void) {
        let resource: Resource<FeedPostResponse, CustomError> = .init(jsonDecoder: JSONDecoder(), path: id)
        self.client.load(resource: resource) {[weak self] result in
            self?.dispatchQueue.async {
                switch result {
                case .success(let response):
                    let realm = try? Realm()
                    guard let feedPostResponse = response.data,
                          let savedPost = FeedPostModel.init(responseModel: feedPostResponse) else {
                        completion(.failure(.custom(.init(message: "Something went Wrong!No Data found!"))))
                        return
                    }
                    try? realm?.write {
                        realm?.add(savedPost, update: .modified)
                        completion(.success(savedPost))
                    }
                case .failure(_):
                    completion(.failure(.custom(.init(message: "Something went wrong!"))))
                }
            }
            
        }
    }
}
