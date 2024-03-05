//
//  FeedModel.swift
//  TalkSocial
//
//  Created by Rohit Pal on 03/03/24.
//

import Foundation
import RealmSwift

class CommentModel: EmbeddedObject {
    @Persisted var commentId: String
    @Persisted var commentMessage: String
    @Persisted var profilePictureUrl: String
    @Persisted var username: String
    @Persisted var postId: String
    
    convenience init(commentId: String, commentMessage: String, profilePictureUrl: String, username: String) {
        self.init()
        self.commentId = commentId
        self.commentMessage = commentMessage
        self.profilePictureUrl = profilePictureUrl
        self.username = username
    }
}

class FeedPostModel: Object {
    @Persisted(primaryKey: true) var postId: String
    @Persisted var username: String
    @Persisted var profilePictureUrl: String
    @Persisted var videoUrl: String
    @Persisted var thumbnailUrl: String
    @Persisted var likes: Int
    @Persisted var caption: String?
    @Persisted var topComments: List<CommentModel>
    @Persisted var timestamp: Date
    @Persisted var isLiked: Bool
    
    convenience init(postId: String, username: String, profilePictureUrl: String, videoUrl: String, thumbnailUrl: String, caption: String?, likes: Int, topComments: List<CommentModel>, timestamp: Date, isLiked: Bool) {
        self.init()
        self.postId = postId
        self.username = username
        self.profilePictureUrl = profilePictureUrl
        self.videoUrl = videoUrl
        self.thumbnailUrl = thumbnailUrl
        self.caption = caption
        self.likes = likes
        self.topComments = topComments
        self.isLiked = isLiked
        self.timestamp = timestamp
    }
    
   
}

class HomeFeedModel: Object {
    @Persisted(primaryKey: true) var id: String
    @Persisted var next: String?
    
    @Persisted var previous: String?
    @Persisted var data: List<FeedPostModel>
    
    convenience init( next: String?, previous: String?, data: List<FeedPostModel>) {
        self.init()
        self.id = Self.defaultPrimaryKey
        self.next = next
        self.previous = previous
        self.data = data
        
    }
    
    static let defaultPrimaryKey = "TalkSocial_HOME_FEED"
}


extension CommentModel {
    convenience init?(responseModel: CommentResponse?) {
        guard let responseModel,
              let commentId = responseModel.commentId,
              let commentMessage = responseModel.commentMessage,
              let profilePictureUrl = responseModel.profilePictureUrl,
              let username = responseModel.username else {
            return nil
        }
        self.init(commentId: commentId, commentMessage: commentMessage, profilePictureUrl: profilePictureUrl, username: username)
    }
}

extension FeedPostModel {
    convenience init?(responseModel: FeedPostResponseData) {
        guard let postId = responseModel.postId,
              let username = responseModel.username,
//              let profilePictureUrl = responseModel.profilePictureUrl,
              let videoUrl = responseModel.videoUrl,
              let thumbnailUrl = responseModel.thumbnailUrl,
              let likes = responseModel.likes
//              let date = responseModel.getTimeStampDate()
        else {
            return nil
        }
        
        let topComments = responseModel.topComments?.compactMap{ CommentModel(responseModel: $0) } ?? []
        let comments: List<CommentModel> = List<CommentModel>()
        comments.append(objectsIn:  topComments)
        self.init(postId: postId, username: username, profilePictureUrl: responseModel.profilePictureUrl ?? "", videoUrl: videoUrl, thumbnailUrl: thumbnailUrl, caption: responseModel.caption, likes: likes, topComments: comments, timestamp: Date(), isLiked: responseModel.isLiked == true)
    }
}



extension HomeFeedModel {
    convenience init?(responseModel: HomeFeedResponse) {
        let data = responseModel.data ?? []
        let posts = data.compactMap({ FeedPostModel(responseModel: $0) })
        var postList: List<FeedPostModel> = List<FeedPostModel>()
        postList.append(objectsIn: posts)
        self.init(next: responseModel.nextCursor, previous: responseModel.previousCursor, data: postList)
    }
    
    func updateWith(cursorType: FeedCursor?, responseModel: HomeFeedResponse, realm: Realm?, onCompletion completion: (([FeedPostModel]) -> Void)? = nil) {
        func update(respData: [FeedPostResponseData], onRealm realm: Realm) -> [FeedPostModel] {
            let posts = respData.compactMap({ FeedPostModel(responseModel: $0) })
            let postList: List<FeedPostModel> = List<FeedPostModel>()
            postList.append(objectsIn: posts)
            postList.forEach { post in
                realm.add(post, update: .modified)
            }
            switch cursorType {
            case .after:
                postList.append(objectsIn: data)
                data.removeAll()
                data.append(objectsIn: postList)
            case .before:
                data.append(objectsIn: postList)
            default:
                data.removeAll()
                data.append(objectsIn: postList)
            }
            return posts
        }
        
        self.next = responseModel.nextCursor
        self.previous = responseModel.previousCursor
        let respData = responseModel.data ?? []
        guard let realm else {
            if let realm = try? Realm() {
                try? realm.write {
                    let upserted = update(respData: respData, onRealm: realm)
                    completion?(upserted)
                }
            }
            return
        }
        let upserted = update(respData: respData, onRealm: realm)
        completion?(upserted)
    }
}


struct CommentResponse: Codable {
    var commentId: String?
    var commentMessage: String?
    var profilePictureUrl: String?
    var username: String?
    var postId: String?
    var parentCommentId: String?
}

struct FeedPostResponseData: Codable {
    var postId: String?
    var username: String?
    var profilePictureUrl: String?
    var videoUrl: String?
    var thumbnailUrl: String?
    var caption: String?
    var likes: Int?
    var topComments: [CommentResponse]?
    var timestamp: String?
    var isLiked: Bool?

    func getTimeStampDate() -> Date? {
        guard let timestamp else { return nil }
        let dateFormater = ISO8601DateFormatter()
        dateFormater.timeZone = TimeZone(abbreviation: "UTC")
        return dateFormater.date(from: timestamp)
    }
}

struct HomeFeedResponse: Codable {
    let status: String?
    let data: [FeedPostResponseData]?
    let nextCursor: String?
    let previousCursor: String?
}


enum FeedCursor {
    case after(String)
    case before(String)
}


extension Array where Element == FeedPostModel {
    func toFeedPostViewModelData() -> [FeedPostViewModelData] {
        self.map { model in
                .init(postId: model.postId, userName: model.username, profileImageUrl: model.profilePictureUrl, likeCount: model.likes, caption: model.caption, topComments: model.topComments.toCommentViewModelData(), videoUrl: model.videoUrl, thumbnailUrl: model.thumbnailUrl, time: model.timestamp, isLiked: model.isLiked)
        }
    }
}

extension List where Element == FeedPostModel {
    func toFeedPostViewModelData() -> [FeedPostViewModelData] {
        self.map { model in
                .init(postId: model.postId, userName: model.username, profileImageUrl: model.profilePictureUrl, likeCount: model.likes, caption: model.caption, topComments: model.topComments.toCommentViewModelData(), videoUrl: model.videoUrl, thumbnailUrl: model.thumbnailUrl, time: model.timestamp, isLiked: model.isLiked)
        }
    }
}

extension List where Element == CommentModel {
    func toCommentViewModelData() -> [CommentViewModelData] {
        self.map { model in
            CommentViewModelData(userName: model.username, profileImageUrl: model.profilePictureUrl, messasge: model.commentMessage, postID: model.postId, commentId: model.commentId, parentCommentId: nil)
        }
    }
}
