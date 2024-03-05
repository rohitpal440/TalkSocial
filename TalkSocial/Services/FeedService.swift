//
//  FeedService.swift
//  TalkSocial
//
//  Created by Rohit Pal on 04/03/24.
//

import Foundation
import RealmSwift

protocol FeedService: AnyObject {
    
    var canFetchUpcomingFeeds: Bool { get }
    
    var canFetchOlderFeeds: Bool { get }
    
    func loadFeed(completion: @escaping ([FeedPostModel]) -> Void)
    func refreshFeeds(completion: @escaping (Result<[FeedPostModel], CustomError>) -> Void)
    func loadUpcomingFeeds(completion: @escaping (Result<[FeedPostModel], CustomError>) -> Void)
    func loadOlderFeeds(completion: @escaping (Result<[FeedPostModel], CustomError>) -> Void)
}



class FeedServiceImpl: FeedService {
    @ThreadSafe private var homeFeed: HomeFeedModel?
    private var client: WebClient = WebClient.init(baseUrl: "https://api.mocklets.com/p6758/api/")
    let dispatchQueue = DispatchQueue(label: "talk_social_backgroundQueue")
    
    func loadFeed(completion: @escaping ([FeedPostModel]) -> Void) {
        dispatchQueue.async {[weak self] in
            self?._loadFeed(completion: completion)
        }
    }
    
    func _loadFeed(completion: @escaping ([FeedPostModel]) -> Void) {
        let realm = try? Realm()
        if let object = self.homeFeed ?? realm?.object(ofType: HomeFeedModel.self, forPrimaryKey: HomeFeedModel.defaultPrimaryKey) {
            let models: [FeedPostModel] =  object.data.map { $0 }
            completion(models)
        } else {
            completion([])
        }
    }
    
    
    func loadUpcomingFeeds(completion: @escaping (Result<[FeedPostModel], CustomError>) -> ()) {
        dispatchQueue.async {[weak self] in
            self?._loadUpcomingFeeds(completion: completion)
        }
    }
    func _loadUpcomingFeeds(completion: @escaping (Result<[FeedPostModel], CustomError>) -> ()) {
        guard canFetchUpcomingFeeds,
              let next = homeFeed?.next else {
            completion(.failure(.custom(.init(message: "No Next cursor supplied"))))
            return
        }
        let cursor = FeedCursor.after(next)
        fetchFeedFromNetwork(cursor: cursor) {[weak self] result in
            self?.saveHomeFeedResult(cursorType: cursor, result: result) { savedObjectResult, addedModels in
                switch savedObjectResult {
                case .success(_):
                    completion(.success(addedModels ?? []))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
//            switch result {
//            case .success(let response):
//                self?.homeFeed?.updateWith(cursorType: cursor, responseModel: response, realm: nil) { updatedPosts in
//                    completion(.success(updatedPosts))
//                }
//                
//            case .failure(let webError):
//                completion(.failure(.custom(.init(message: "Something went wrong!"))))
//            }
        }
    }
    
    func loadOlderFeeds(completion: @escaping (Result<[FeedPostModel], CustomError>) -> Void) {
        dispatchQueue.async {[weak self] in
            self?._loadOlderFeeds(completion: completion)
        }
    }
    
    func _loadOlderFeeds(completion: @escaping (Result<[FeedPostModel], CustomError>) -> Void) {
        guard canFetchUpcomingFeeds,
              let previous  = homeFeed?.previous else {
            completion(.failure(.custom(.init(message: "No Prev cursor supplied"))))
            return
        }
        let cursor = FeedCursor.after(previous)
        fetchFeedFromNetwork(cursor: cursor) {[weak self] result in
            self?.saveHomeFeedResult(cursorType: cursor, result: result) { savedObjectResult, addedModels in
                switch savedObjectResult {
                case .success(_):
                    completion(.success(addedModels ?? []))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
//            switch result {
//            case .success(let response):
//                self?.homeFeed?.updateWith(cursorType: cursor, responseModel: response, realm: nil) { updatedPosts in
//                    completion(.success(updatedPosts))
//                }
//                
//            case .failure(let webError):
//                completion(.failure(.custom(.init(message: "Something went wrong!"))))
//            }
        }
    }
    
    func refreshFeeds(completion: @escaping (Result<[FeedPostModel], CustomError>) -> Void) {
        dispatchQueue.async {[weak self] in
            self?._refreshFeeds(completion: completion)
        }
    }
    
    private func _refreshFeeds(completion: @escaping (Result<[FeedPostModel], CustomError>) -> Void) {
        fetchFeedFromNetwork(cursor: nil) {[weak self] result in
            self?.saveHomeFeedResult(cursorType: nil, result: result) { savedObjectResult, addedPosts in
                switch savedObjectResult {
                case .success(_):
                    completion(.success(addedPosts ?? []))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
//            switch result {
//            case .success(let response):
//                self?.executeRealm {[weak self] realm in
//                    do {
//                        var homeFeedObject = self?.homeFeed ?? realm.object(ofType: HomeFeedModel.self, forPrimaryKey: HomeFeedModel.defaultPrimaryKey)
//                        
//                        if let object = homeFeedObject {
//                            try realm.write {
//                                object.updateWith(cursorType: nil, responseModel: response, realm: realm) { posts in
//                                    completion(.success(posts))
//                                }
//                            }
//                        } else if let newObject = HomeFeedModel(responseModel: response) {
//                            try realm.write {
//                                realm.add(newObject)
//    //                            realm.add(newObject, update: .modified)
//                                completion(.success(newObject.data.map { $0 }))
//                            }
//                        }
//                    } catch {
//                        completion(.failure(.custom(.init(message: "Something went wrong"))))
//                    }
//                }
//                
//                
//            case .failure(let webError):
//                completion(.failure(.custom(.init(message: "Something went wrong"))))
//            }
        }
    }
    
    private func saveHomeFeedResult(cursorType: FeedCursor?, result: Result<HomeFeedResponse, CustomError>, completion: @escaping (_ savedModelResult: Result<HomeFeedModel, CustomError>, _ addedPosts: [FeedPostModel]?) -> Void) {
        self.executeRealm {[weak self] realm in
            switch result {
            case .success(let response):
                do {
                    var homeFeedObject = self?.homeFeed ?? realm.object(ofType: HomeFeedModel.self, forPrimaryKey: HomeFeedModel.defaultPrimaryKey)
                    
                    if let object = homeFeedObject {
                        try realm.write {
                            object.updateWith(cursorType: cursorType, responseModel: response, realm: realm) { posts in
                                completion(.success(object), posts)
                            }
                        }
                    } else if let newObject = HomeFeedModel(responseModel: response) {
                        try realm.write {
                            realm.add(newObject)
    //                            realm.add(newObject, update: .modified)
                            completion(.success(newObject), Array(newObject.data))
                        }
                    }
                } catch {
                    completion(.failure(.custom(.init(message: "Something went wrong"))), nil)
                }

            case .failure(let webError):
                completion(.failure(.custom(.init(message: "Something went wrong"))), nil)
            }
        }
        
    }
    
    private func executeRealm(_ block: @escaping (Realm) -> Void) {
        dispatchQueue.async {
            do {
                let realm = try Realm()
                block(realm)
            } catch {
                print(error)
                fatalError("Failed to open realm!")
            }
        }
        
    }
    
    var canFetchUpcomingFeeds: Bool {
        self.homeFeed?.next != nil
    }
    
    var canFetchOlderFeeds: Bool {
        self.homeFeed?.previous != nil
    }
    
    private func prepareResourceWith(cursor: FeedCursor?) -> Resource<HomeFeedResponse, CustomError> {
        var params: JSON = [:]
        switch cursor {
        case .after(let newerPostCursor):
            params = ["cursor": newerPostCursor]
        case .before(let olderPostCursor):
            params = ["cursor": olderPostCursor]
        default:
            break
        }
        return .init(jsonDecoder: JSONDecoder(), path: "feed", params: params)
    }
    
    private func fetchFeedFromNetwork(cursor: FeedCursor?, completion: @escaping (Result<HomeFeedResponse, CustomError>) -> ()) {
        let resource = prepareResourceWith(cursor: cursor)
        
        self.client.load(resource: resource) {[weak self] result in
            self?.dispatchQueue.async {
                completion(result)
            }
        }
    }
}



