import UIKit

/// A rounded card holding a vertical stack.
final class StoreCardView: UIView {
    let content = UIStackView()

    init(identifier: String) {
        super.init(frame: .zero)
        accessibilityIdentifier = identifier
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        content.axis = .vertical
        content.alignment = .fill
        content.spacing = 8
        content.isLayoutMarginsRelativeArrangement = true
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }
}

/// The Store (spec 5.2): a scrollable stack of cards drawn from
/// `StoreService.screenModel()`. Every rule about what is shown lives in
/// `StoreScreenModel`; buying, restoring and Manage subscription go to the
/// service. iPhone pushes it on the navigation controller, iPad presents it
/// as a form sheet. System fonts and colours only, so Dynamic Type and dark
/// mode follow; the content width follows the readable content guide.
@MainActor
@objc final class StoreViewController: UIViewController {
    enum Presentation: Equatable {
        case push
        case formSheet
    }

    static let privacyPolicyAddress = "https://www.pente.org/help/helpWindow.jsp?file=privacyPolicy"
    static let eulaAddress = "https://www.pente.org/help/helpWindow.jsp?file=eula"
    static let disclosureText = NSLocalizedString(
        "The subscription renews automatically every year at the same price unless it is cancelled at least 24 hours before the end of the current period. Payment is charged to your Apple Account. Cancel it any time with Manage subscription below.",
        comment: "")

    let service: StoreService

    /// Tests and screenshots draw this fixed state instead of the service's.
    var modelOverride: StoreScreenModel? {
        didSet {
            if isViewLoaded { render() }
        }
    }

    private(set) var renderedModel: StoreScreenModel?

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let statusLabel = StoreViewController.makeLabel(.body, "store.status", color: .secondaryLabel)
    private let headerLabel = StoreViewController.makeLabel(.headline, "store.subscribedUntil")

    private let yearlyCard = StoreCardView(identifier: "store.yearly")
    private let yearlyTitle = StoreViewController.makeLabel(.title3, "store.yearly.title")
    private let yearlyBenefits = StoreViewController.makeLabel(.body, "store.yearly.benefits")
    private let yearlyPrice = StoreViewController.makeLabel(.headline, "store.yearly.price")
    private let yearlyOverlap = StoreViewController.makeLabel(.footnote, "store.yearly.overlap", color: .systemOrange)
    private let yearlyOwned = StoreViewController.makeLabel(.footnote, "store.yearly.owned", color: .secondaryLabel)
    private let subscribeButton = StoreViewController.makeButton(filled: true, "store.yearly.subscribe")
    private let yearlyDisclosure = StoreViewController.makeLabel(.caption1, "store.yearly.disclosure", color: .secondaryLabel)
    private let privacyButton = StoreViewController.makeButton(filled: false, "store.privacy")
    private let eulaButton = StoreViewController.makeButton(filled: false, "store.eula")

    private let monthCard = StoreCardView(identifier: "store.month")
    private let monthTitle = StoreViewController.makeLabel(.title3, "store.month.title")
    private let monthDetail = StoreViewController.makeLabel(.body, "store.month.detail")
    private let monthNote = StoreViewController.makeLabel(.footnote, "store.month.note", color: .secondaryLabel)
    private let monthButton = StoreViewController.makeButton(filled: true, "store.month.buy")

    private let vacationCard = StoreCardView(identifier: "store.vacation")
    private let vacationTitle = StoreViewController.makeLabel(.title3, "store.vacation.title")
    private let vacationDaysLeft = StoreViewController.makeLabel(.body, "store.vacation.daysLeft")
    private let vacationNote = StoreViewController.makeLabel(.footnote, "store.vacation.note", color: .secondaryLabel)
    private let vacationButtons = UIStackView()
    private var drawnVacationOptions: [StoreScreenModel.VacationOption]?

    private let restoreButton = StoreViewController.makeButton(filled: false, "store.restore")
    private let manageButton = StoreViewController.makeButton(filled: false, "store.manage")

    init(service: StoreService = .shared) {
        self.service = service
        super.init(nibName: nil, bundle: nil)
        title = NSLocalizedString("Store", comment: "")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Presentation

    /// Opens the Store from any screen (spec 5.4): pushed on iPhone, a form
    /// sheet with a Done button on iPad (or when there is no navigation
    /// controller to push on).
    @objc(presentFrom:)
    static func present(from presenter: UIViewController) {
        let store = StoreViewController()
        switch presentation(idiom: UIDevice.current.userInterfaceIdiom,
                            hasNavigationController: presenter.navigationController != nil) {
        case .push:
            presenter.navigationController?.pushViewController(store, animated: true)
        case .formSheet:
            store.navigationItem.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .done, target: store, action: #selector(StoreViewController.doneTapped))
            let sheet = UINavigationController(rootViewController: store)
            sheet.modalPresentationStyle = .formSheet
            presenter.present(sheet, animated: true)
        }
    }

    static func presentation(idiom: UIUserInterfaceIdiom, hasNavigationController: Bool) -> Presentation {
        idiom == .phone && hasNavigationController ? .push : .formSheet
    }

    static func subscribedUntilText(_ date: Date) -> String {
        String(format: NSLocalizedString("Subscribed until %@", comment: ""),
               DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none))
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        layOut()
        fillStaticText()
        wireActions()
        NotificationCenter.default.addObserver(self, selector: #selector(serviceChanged),
                                               name: StoreService.didChangeNotification, object: service)
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification, object: nil)
        render()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        service.storeVisibilityChanged(true)
        render()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        service.storeVisibilityChanged(false)
    }

    // MARK: - Drawing

    func render() {
        guard isViewLoaded else { return }
        let model = modelOverride ?? service.screenModel()
        renderedModel = model

        statusLabel.text = model.status.message
        statusLabel.isHidden = model.status.message == nil
        headerLabel.text = model.subscribedUntil.map(Self.subscribedUntilText)
        headerLabel.isHidden = model.subscribedUntil == nil

        if let yearly = model.yearly {
            yearlyCard.isHidden = false
            yearlyPrice.text = String(format: NSLocalizedString("%@ / year", comment: ""), yearly.price)
            yearlyOwned.isHidden = !yearly.showOwnedHint
            yearlyOverlap.isHidden = !yearly.showOverlapWarning
            subscribeButton.isEnabled = model.buyEnabled && yearly.subscribeEnabled
        } else {
            yearlyCard.isHidden = true
        }

        if let month = model.monthPass {
            monthCard.isHidden = false
            monthButton.configuration?.title = String(format: NSLocalizedString("Buy 1 month: %@", comment: ""),
                                                      month.price)
            monthNote.isHidden = !month.showStartsLaterNote
            monthButton.isEnabled = model.buyEnabled
        } else {
            monthCard.isHidden = true
        }

        if let vacation = model.vacation {
            vacationCard.isHidden = false
            vacationDaysLeft.text = String(format: NSLocalizedString("You have %ld vacation days left", comment: ""),
                                           vacation.daysLeft)
            vacationNote.text = String(format: NSLocalizedString("These vacation days do not roll over to %ld.",
                                                                 comment: ""), vacation.nextYear)
            // Rebuilt only when the packs changed: change notifications come
            // in bursts right after the Store opens, and a rebuild mid-tap
            // would drop the tap.
            if vacation.options != drawnVacationOptions {
                drawnVacationOptions = vacation.options
                vacationButtons.arrangedSubviews.forEach { $0.removeFromSuperview() }
                for option in vacation.options {
                    let button = Self.makeButton(filled: true, "store.vacation.\(option.productID)")
                    button.configuration?.title = String(format: NSLocalizedString("Extra vacation days (%ld): %@",
                                                                                   comment: ""),
                                                         option.days, option.price)
                    button.addTarget(self, action: #selector(vacationTapped(_:)), for: .touchUpInside)
                    vacationButtons.addArrangedSubview(button)
                }
            }
            vacationButtons.arrangedSubviews.forEach { ($0 as? UIButton)?.isEnabled = model.buyEnabled }
        } else {
            vacationCard.isHidden = true
        }

        restoreButton.isHidden = model.status == .loggedOut
        restoreButton.isEnabled = model.restoreEnabled
        manageButton.isEnabled = true
    }

    private func layOut() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // Vertical scrolling only: the content is as wide as the frame.
            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: view.readableContentGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.readableContentGuide.trailingAnchor),
        ])

        let links = UIStackView(arrangedSubviews: [privacyButton, eulaButton])
        links.axis = .vertical
        links.alignment = .leading
        links.spacing = 0
        for view in [yearlyTitle, yearlyBenefits, yearlyPrice, yearlyOverlap, yearlyOwned, subscribeButton,
                     yearlyDisclosure, links] as [UIView] {
            yearlyCard.content.addArrangedSubview(view)
        }
        for view in [monthTitle, monthDetail, monthNote, monthButton] as [UIView] {
            monthCard.content.addArrangedSubview(view)
        }
        vacationButtons.axis = .vertical
        vacationButtons.alignment = .fill
        vacationButtons.spacing = 8
        for view in [vacationTitle, vacationDaysLeft, vacationButtons, vacationNote] as [UIView] {
            vacationCard.content.addArrangedSubview(view)
        }
        for view in [statusLabel, headerLabel, yearlyCard, monthCard, vacationCard, restoreButton,
                     manageButton] as [UIView] {
            stack.addArrangedSubview(view)
        }
    }

    private func fillStaticText() {
        yearlyTitle.text = NSLocalizedString("1 year subscription", comment: "")
        yearlyBenefits.text = NSLocalizedString(
            "\u{2022} No play limits\n\u{2022} Request undo in turn-based games\n\u{2022} Name colour and avatar\n\u{2022} Database access",
            comment: "")
        yearlyOwned.text = NSLocalizedString("You already have this subscription. Use Manage subscription below.",
                                             comment: "")
        yearlyOverlap.text = NSLocalizedString(
            "You already have access until the date above. A new subscription starts now and runs alongside your current access; it is not added on after it.",
            comment: "")
        yearlyDisclosure.text = Self.disclosureText
        subscribeButton.configuration?.title = NSLocalizedString("Subscribe", comment: "")
        privacyButton.configuration?.title = NSLocalizedString("Privacy Policy", comment: "")
        eulaButton.configuration?.title = NSLocalizedString("Terms of Use (EULA)", comment: "")
        monthTitle.text = NSLocalizedString("1 month pass", comment: "")
        monthDetail.text = NSLocalizedString("31 days", comment: "")
        monthNote.text = NSLocalizedString("Your pass starts when your current access ends.", comment: "")
        vacationTitle.text = NSLocalizedString("Extra vacation days (no subscription required)", comment: "")
        restoreButton.configuration?.title = NSLocalizedString("Restore purchases", comment: "")
        manageButton.configuration?.title = NSLocalizedString("Manage subscription", comment: "")
    }

    private func wireActions() {
        subscribeButton.addTarget(self, action: #selector(subscribeTapped), for: .touchUpInside)
        monthButton.addTarget(self, action: #selector(monthTapped), for: .touchUpInside)
        privacyButton.addTarget(self, action: #selector(privacyTapped), for: .touchUpInside)
        eulaButton.addTarget(self, action: #selector(eulaTapped), for: .touchUpInside)
        restoreButton.addTarget(self, action: #selector(restoreTapped), for: .touchUpInside)
        manageButton.addTarget(self, action: #selector(manageTapped), for: .touchUpInside)
    }

    private static func makeLabel(_ style: UIFont.TextStyle, _ identifier: String,
                                  color: UIColor = .label) -> UILabel {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.textColor = color
        label.accessibilityIdentifier = identifier
        return label
    }

    private static func makeButton(filled: Bool, _ identifier: String) -> UIButton {
        var configuration: UIButton.Configuration = filled ? .filled() : .plain()
        configuration.titleAlignment = .center
        configuration.titleLineBreakMode = .byWordWrapping
        let button = UIButton(configuration: configuration)
        button.accessibilityIdentifier = identifier
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        return button
    }

    // MARK: - Actions

    @objc private func subscribeTapped() { buy(StoreProducts.yearly) }

    @objc private func monthTapped() { buy(StoreProducts.monthPass) }

    @objc private func vacationTapped(_ sender: UIButton) {
        let prefix = "store.vacation."
        guard let identifier = sender.accessibilityIdentifier, identifier.hasPrefix(prefix) else { return }
        buy(String(identifier.dropFirst(prefix.count)))
    }

    private func buy(_ productID: String) {
        let scene = view.window?.windowScene
        Task { await self.service.buy(productID: productID, scene: scene) }
    }

    @objc private func restoreTapped() {
        Task { await self.service.restore() }
    }

    @objc private func manageTapped() {
        let scene = view.window?.windowScene
        Task { await self.service.manageSubscriptions(in: scene) }
    }

    @objc private func privacyTapped() { openPage(Self.privacyPolicyAddress) }

    @objc private func eulaTapped() { openPage(Self.eulaAddress) }

    private func openPage(_ address: String) {
        navigationController?.pushViewController(PenteWebViewController(address: address), animated: true)
    }

    @objc private func doneTapped() {
        dismiss(animated: true)
    }

    @objc private func serviceChanged() {
        render()
    }

    /// Spec 5.2: back in the foreground while visible, reload the store info
    /// (a cancellation in the App Store shows). The service resyncs itself.
    @objc private func willEnterForeground() {
        guard view.window != nil else { return }
        Task { await self.service.loadInfo() }
    }
}
