//
//  GetPostsResponse.swift
//  app
//
//  Created by VTIT on 16/8/24.
//


import Foundation

// MARK: - PostsResponse
struct GetPostsResponse: Codable {
    let posts: [PostResponse]?
    let total, skip, limit: Int?
}

// MARK: - Post
struct PostResponse: Codable {
    let id: Int?
    let title, body: String?
    let tags: [String]?
    let reactions: ReactionsResponse?
    let views, userID: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, body, tags, reactions, views
        case userID = "userId"
    }
}

// MARK: - Reactions
struct ReactionsResponse: Codable {
    let likes, dislikes: Int?
}

