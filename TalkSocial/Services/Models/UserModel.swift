//
//  UserModel.swift
//  TalkSocial
//
//  Created by Rohit Pal on 05/03/24.
//

import Foundation
import RealmSwift

struct UserProfileResponse: Codable {
    let status: String?
    let data: UserModelResponse?
}

struct UserModelResponse: Codable {
    let username: String
    let about: String?
    let profilePictureUrl: String?
    let nextCursor: String?
    let posts: [FeedPostResponseData]?
}


class UserModel: Object {
    @Persisted(primaryKey: true) var username: String
    @Persisted var profilePictureUrl: String?
    @Persisted var about: String?
    @Persisted var posts: List<FeedPostModel>
    @Persisted var nextCursor: String?
    
    convenience init(username: String, profilePictureUrl: String?, about: String? = nil, posts: List<FeedPostModel>, nextCursor: String?) {
        self.init()
        self.username = username
        self.profilePictureUrl = profilePictureUrl
        self.about = about
        self.nextCursor = nextCursor
        self.posts = posts
    }
    
    convenience init(userModelResponse resp: UserModelResponse) {
        let posts: [FeedPostModel] = (resp.posts ?? []).map { FeedPostModel(responseModel: $0) }.compactMap({$0})
        let postList = List<FeedPostModel>()
        postList.append(objectsIn: posts)
        self.init(username: resp.username, profilePictureUrl: resp.profilePictureUrl, about: resp.about, posts: postList, nextCursor: resp.nextCursor)
    }
    
    func updateWith(cursorId: String?, responseModel: UserModelResponse, realm: Realm?, onCompletion completion: (([FeedPostModel]) -> Void)? = nil) {
        func update(respData: [FeedPostResponseData], onRealm realm: Realm) -> [FeedPostModel] {
            let postResp = respData.compactMap({ FeedPostModel(responseModel: $0) })
            let postList: List<FeedPostModel> = List<FeedPostModel>()
            postList.append(objectsIn: postResp)
            postList.forEach { post in
                realm.add(post, update: .modified)
            }

            if cursorId != nil {
                self.posts.append(objectsIn: postList)
            } else {
                self.posts.removeAll()
                self.posts.append(objectsIn: postList)
            }
            return postResp
        }

        self.nextCursor = responseModel.nextCursor
        let respData = responseModel.posts ?? []
        guard let realm else {
            DispatchQueue(label: "talk_social_backgroundQueue").async {
                if let realm = try? Realm() {
                    try? realm.write {
                        let upserted = update(respData: respData, onRealm: realm)
                        completion?(upserted)
                    }
                }
            }
            return
        }
        let upserted = update(respData: respData, onRealm: realm)
        completion?(upserted)
    }
   
}
