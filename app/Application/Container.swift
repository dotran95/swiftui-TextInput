//
//  Container.swift
//  app
//
//  Created by dotn on 15/8/24.
//

import Swinject

struct DIContainer {
    private let container: Container

    func resolve<Service>(_ serviceType: Service.Type) -> Service? {
        return container.resolve(serviceType)
    }

    init() {
        container = Container()

        // MARK: - DataSources
        container.register(RemoteDataSourceProtocol.self) { _ in RemoteDataSourceImpl() }

        // MARK: - Repositoris
        container.register(UserRepositoryProtocol.self) { r in UserRepositoryImpl(remoteDataSource: r.resolve(RemoteDataSourceProtocol.self)!) }
        container.register(PostRepositoryProtocol.self) { r in PostRepositoryImpl(remoteDataSource: r.resolve(RemoteDataSourceProtocol.self)!) }
        container.register(AuthRepositoryProtocol.self) { r in AuthRepositoryImpl(remoteDataSource: r.resolve(RemoteDataSourceProtocol.self)!) }

        // MARK: - Usecases
        container.register(GetUserUsecaseProtocol.self) { r in GetUserUsecaseImpl(repository: r.resolve(UserRepositoryProtocol.self)!) }
        container.register(LoginUsecaseProtocol.self) { r in LoginUsecaseImpl(repository: r.resolve(AuthRepositoryProtocol.self)!) }
        container.register(GetPostsUsecaseProtocol.self) { r in GetPostsUsecaseImpl(repository: r.resolve(PostRepositoryProtocol.self)!) }
    }

}
