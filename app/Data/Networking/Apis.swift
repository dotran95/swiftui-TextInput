//
//  PostAPI.swift
//  app
//
//  Created by dotn on 8/8/24.
//

import Foundation
import Moya

enum Apis {
    case login(body: Encodable)
    case getUserInfo
    case posts(limit: Int, skip: Int)
}

extension Apis: TargetType, AccessTokenAuthorizable {
    var authorizationType: Moya.AuthorizationType? {
        switch self {
        // UnAuth
        case .login: return .none

        // Auth
        case .getUserInfo, .posts: return .bearer
        }
    }

    var baseURL: URL {
        return URL(string: Configs.share.baseUrl)!
    }

    var path: String {
        switch self {
        // UnAuth
        case .login: return "/auth/login"

        // Auth
        case .getUserInfo: return "/auth/me"
        case .posts: return "/posts"
        }
    }

    var method: Moya.Method {
        switch self {
        // UnAuth
        case .login: return .post

        // Auth
        case .getUserInfo, .posts: return .get
        }
    }

    var task: Moya.Task {
        switch self {
        // UnAuth
        case .login(let body): return .requestJSONEncodable(body)

        // Auth
        case .getUserInfo: return .requestPlain
        case .posts(let limit, let skip): return .requestParameters(parameters: ["limit": limit, "skip": skip], encoding: URLEncoding.default)
        }
    }

    var headers: [String: String]? {
        nil
    }
}
