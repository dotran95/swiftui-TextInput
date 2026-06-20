//
//  PostModel.swift
//  app
//
//  Created by VTIT on 16/8/24.
//

import Foundation

struct PostModel: Codable {
    let id: Int?
    let title, body: String?
    let tags: [String]?
    let reactions: ReactionsModel?
    let views, userID: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, body, tags, reactions, views
        case userID = "userId"
    }

    static func fromApi(_ obj: PostResponse) -> PostModel {
        return PostModel(id: obj.id,
                         title: obj.title,
                         body: obj.body,
                         tags: obj.tags ?? [],
                         reactions: obj.reactions.map({ ReactionsModel(likes: $0.likes, dislikes: $0.dislikes) }),
                         views: obj.views,
                         userID: obj.userID)
    }
}

struct ReactionsModel: Codable {
    let likes, dislikes: Int?
}
