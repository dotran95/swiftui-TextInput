//
//  ChatBackgroundHostingController.swift
//  app
//

import SwiftUI
import UIKit

/// UIKit entry point that embeds `ChatBackgroundPickerView`, for presenting this SwiftUI
/// flow from the existing storyboard/RxSwift screens (e.g. Chat Detail's background action).
final class ChatBackgroundHostingController: UIHostingController<ChatBackgroundPickerView> {
    init(onFinish: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
        super.init(rootView: ChatBackgroundPickerView(onFinish: onFinish, onCancel: onCancel))
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
