import Combine
import UIKit

/// UI-only like button. Forwards taps to `ReactionController` and renders display updates.
public final class LikeButton: UIControl {

    // MARK: - Public

    public let controller: ReactionController

    // MARK: - UI

    private let imageView = UIImageView()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Appearance

    public var heartImage: UIImage? {
        didSet { refreshAppearance(animated: false) }
    }

    public var emptyImage: UIImage? {
        didSet { refreshAppearance(animated: false) }
    }

    public var heartTintColor: UIColor = .systemRed {
        didSet { refreshAppearance(animated: false) }
    }

    public var emptyTintColor: UIColor = .secondaryLabel {
        didSet { refreshAppearance(animated: false) }
    }

    // MARK: - Init

    public init(controller: ReactionController) {
        self.controller = controller
        super.init(frame: .zero)
        configure()
        bind()
    }

    public convenience init(
        initialServerReaction: OAReaction = .none,
        configuration: ReactionControllerConfiguration = ReactionControllerConfiguration()
    ) {
        let controller = ReactionController(
            initialServerReaction: initialServerReaction,
            configuration: configuration
        )
        self.init(controller: controller)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        cancellables.removeAll()
    }

    // MARK: - Setup

    private func configure() {
        isAccessibilityElement = true
        accessibilityTraits = .button

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        addTarget(self, action: #selector(handleTouchUpInside), for: .touchUpInside)
        refreshAppearance(animated: false)
    }

    private func bind() {
        controller.displayPublisher
            .sink { [weak self] reaction in
                self?.refreshAppearance(animated: true, reaction: reaction)
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func handleTouchUpInside() {
        controller.acceptTap()
    }

    // MARK: - Rendering

    private func refreshAppearance(animated: Bool, reaction: OAReaction? = nil) {
        let reaction = reaction ?? controller.currentDisplay
        let isHeart = reaction == .heart

        accessibilityLabel = isHeart ? "Unlike" : "Like"
        accessibilityValue = isHeart ? "Liked" : "Not liked"

        let apply = { [weak self] in
            guard let self else { return }
            if let heartImage = self.heartImage, let emptyImage = self.emptyImage {
                self.imageView.image = isHeart ? heartImage : emptyImage
                self.imageView.tintColor = nil
            } else {
                let symbolName = isHeart ? "heart.fill" : "heart"
                let configuration = UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)
                self.imageView.image = UIImage(systemName: symbolName, withConfiguration: configuration)
                self.imageView.tintColor = isHeart ? self.heartTintColor : self.emptyTintColor
            }
            self.imageView.transform = isHeart
                ? CGAffineTransform(scaleX: 1.08, y: 1.08)
                : .identity
        }

        guard animated else {
            apply()
            return
        }

        UIView.animate(
            withDuration: 0.18,
            delay: 0,
            usingSpringWithDamping: 0.62,
            initialSpringVelocity: 0.8,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: apply
        )
    }
}
