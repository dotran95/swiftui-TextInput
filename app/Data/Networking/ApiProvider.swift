//
//  ApiProvider.swift
//  app
//
//  Created by dotn on 9/8/24.
//

import Moya

final class ApiProvider<Target: TargetType>: MoyaProvider<Target> {

    init(plugins: [PluginType]) {
        var plugins = plugins
        if Configs.share.loggingEnabled {
            plugins.append(NetworkLoggerPlugin(configuration: .init(logOptions: .default)))
        }
        super.init(plugins: plugins)
    }
}
