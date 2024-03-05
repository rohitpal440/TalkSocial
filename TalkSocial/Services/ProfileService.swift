//
//  ProfileService.swift
//  TalkSocial
//
//  Created by Rohit Pal on 05/03/24.
//

import Foundation
import RealmSwift

protocol ProfileService: AnyObject {
    var username: String { get }
    var about: String? { get }
    var profilePicUrl: String? { get }
    var canFetchOlderPosts: Bool { get }
    
    var hasNotPostedAnything: Bool? { get }
    func loadProfile(completion: @escaping (Result<UserModel, CustomError>) -> Void)
    
    func loadOlderPost(completion: @escaping (Result<[FeedPostModel], CustomError>) -> Void)
    func refreshProfile(completion: @escaping (Result<UserModel, CustomError>) -> Void)
}

class ProfileServiceImpl: ProfileService {
    let username: String
    var about: String?
    var profilePicUrl: String?
    var nextCursor: String?
    private let client: WebClient = WebClient.init(baseUrl: "https://api.mocklets.com/p6758/api/profile/")
    private let dispatchQueue = DispatchQueue(label: "talk_social_backgroundQueue")
    
    var hasNotPostedAnything: Bool?
    
    @ThreadSafe private  var profileModel: UserModel? {
        didSet {
            updateData()
        }
    }
    init(username: String) {
        self.username = username
    }
    
    private func updateData() {
        guard let profileModel else {
            hasNotPostedAnything = nil
            return
        }
        hasNotPostedAnything = profileModel.posts.isEmpty  && profileModel.nextCursor != nil
        about = profileModel.about
        profilePicUrl = profileModel.profilePictureUrl
        nextCursor = profileModel.nextCursor
    }
    
    func loadProfile(completion: @escaping (Result<UserModel, CustomError>) -> Void) {
        let username = self.username
        let resource: Resource<UserProfileResponse, CustomError> = .init(jsonDecoder: JSONDecoder(), path: username)
        self.client.load(resource: resource) {[weak self] result in
            self?.executeRealm { realm in
                do {
                    switch result {
                    case .success(let response):
                        guard let userModelResponse = response.data else {
                            completion(.failure(.custom(.init(message: "Something went Wrong!No Data found!"))))
                            return
                        }
                        let userModel = UserModel(userModelResponse: userModelResponse)
                        try realm.write {
                            realm.add(userModel, update: .modified)
                            self?.profileModel = userModel
                            completion(.success(userModel))
                        }
                    case .failure(_):
                        if let cachedObject = realm.object(ofType: UserModel.self, forPrimaryKey: username) {
                            self?.profileModel = cachedObject
                            completion(.success(cachedObject))
                        } else {
                            completion(.failure(.custom(.init(message: "Something went wrong!"))))
                        }
                    }
                }
                catch {
                    completion(.failure(.custom(.init(message: "Something went wrong!"))))
                }
                
            }
            
        }
    }
    
    func loadOlderPost(completion: @escaping (Result<[FeedPostModel], CustomError>) -> Void) {
        guard canFetchOlderPosts,
              let cursorId  = nextCursor else {
            completion(.failure(.custom(.init(message: "No Prev cursor supplied"))))
            return
        }
        fetchProfileFromNetwork(cursorId: cursorId) {[weak self] result in
            self?.saveProfile(cursorId: cursorId, result: result) { _, newlyAddedPosts in
                switch result {
                case .success(let response):
                    completion(.success(newlyAddedPosts ?? []))
                    
                case .failure(let webError):
                    completion(.failure(.custom(.init(message: "Something went wrong!"))))
                }
            }
            
        }
    }
    
    

    func refreshProfile(completion: @escaping (Result<UserModel, CustomError>) -> Void) {
        dispatchQueue.async {[weak self] in
            self?._refreshProfile(completion: completion)
        }
    }
    
    private func _refreshProfile(completion: @escaping (Result<UserModel, CustomError>) -> Void) {
        fetchProfileFromNetwork(cursorId: nil) {[weak self] result in
            self?.saveProfile(cursorId: nil, result: result) { savedResult, _ in
                completion(savedResult)
            }
        }
    }
    
    var canFetchOlderPosts: Bool {
        nextCursor != nil
    }
    
    private func saveProfile(cursorId: String?, result: Result<UserProfileResponse, CustomError>, completion: @escaping (Result<UserModel, CustomError>, _ newlyAddedPosts: [FeedPostModel]?) -> Void) {
        let primaryKey = username
        self.executeRealm {[weak self] realm in
            switch result {
            case .success(let response):
                guard let data = response.data else {
                    completion(.failure(.custom(.init(message: "Something went wrong!"))), nil)
                    return
                }
                do {
                    var profileObject = self?.profileModel ?? realm.object(ofType: UserModel.self, forPrimaryKey: primaryKey)
                    
                    if let objectT = profileObject {
                        try realm.write {
                            objectT.nextCursor = data.nextCursor
                            objectT.updateWith(cursorId: cursorId, responseModel: data, realm: realm) { addedPosts in
                                self?.profileModel = objectT
                                completion(.success(objectT), addedPosts)
                            }
                        }
                        
                        
                    } else {
                        let newObject = UserModel(userModelResponse: data)
                        try realm.write {
                            realm.add(newObject)
                            self?.profileModel = newObject
                            completion(.success(newObject), Array(newObject.posts))
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
                fatalError("Failed to open realm!")
            }
        }
        
    }
    
    private func prepareResourceWith(cursorId: String?) -> Resource<UserProfileResponse, CustomError> {
        var params: JSON = [:]
        if let cursorId {
            params["cursor"] = cursorId
        }
        return .init(jsonDecoder: JSONDecoder(), path: username, params: params)
    }
    
    
    private func fetchProfileFromNetwork(cursorId: String?, completion: @escaping (Result<UserProfileResponse, CustomError>) -> ()) {
        let resource = prepareResourceWith(cursorId: cursorId)
        self.client.load(resource: resource) {[weak self] result in
            self?.dispatchQueue.async {
                completion(result)
            }
        }
    }
    
}
