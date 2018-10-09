//  MessageViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore

private let Log = Logger.get()

/// Displays a single private message.
final class MessageViewController: ViewController {
    
    private var composeVC: MessageComposeViewController?
    private var didLoadOnce = false
    private var didRender = false
    private var fractionalContentOffsetOnLoad: CGFloat = 0
    private var loadingView: LoadingView?
    private let privateMessage: PrivateMessage
    
    private lazy var renderView: RenderView = {
        let renderView = RenderView(frame: CGRect(origin: .zero, size: view.bounds.size))
        renderView.delegate = self
        return renderView
    }()
    
    private lazy var replyButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(image: UIImage(named: "reply"), style: .plain, target: self, action: #selector(didTapReplyButtonItem))
    }()
    
    init(privateMessage: PrivateMessage) {
        self.privateMessage = privateMessage
        super.init(nibName: nil, bundle: nil)
        
        title = privateMessage.subject
        
        navigationItem.rightBarButtonItem = replyButtonItem
        hidesBottomBarWhenPushed = true
        
        restorationClass = type(of: self)
        
        NotificationCenter.default.addObserver(self, selector: #selector(settingsDidChange), name: .AwfulSettingsDidChange, object: nil)
    }
    
    override var title: String? {
        didSet { navigationItem.titleLabel.text = title }
    }
    
    private func renderMessage() {
        let viewModel = PrivateMessageViewModel(message: privateMessage, stylesheet: theme["postsViewCSS"])
        do {
            let rendering = try MustacheTemplate.render(.privateMessage, value: viewModel)
            renderView.render(html: rendering, baseURL: ForumsClient.shared.baseURL)
        } catch {
            Log.e("failed to render private message: \(error)")
            
            // TODO: show error nicer
            renderView.render(html: "<h1>Rendering Error</h1><pre>\(error)</pre>", baseURL: nil)
        }
        didRender = true
    }
    
    @objc private func settingsDidChange(_ notification: Notification) {
        guard isViewLoaded else { return }
        
        switch notification.userInfo?[AwfulSettingsDidChangeSettingKey] as? NSString {
        case AwfulSettingsKeys.showAvatars.takeUnretainedValue()?:
            renderView.setShowAvatars(AwfulSettings.shared().showAvatars)
            
        case AwfulSettingsKeys.showImages.takeUnretainedValue()?:
            renderView.loadLinkifiedImages()
            
        case AwfulSettingsKeys.fontScale.takeUnretainedValue()?:
            renderView.setFontScale(AwfulSettings.shared().fontScale)
            
        case AwfulSettingsKeys.handoffEnabled.takeUnretainedValue()? where visible:
            configureUserActivity()
            
        case AwfulSettingsKeys.embedTweets.takeUnretainedValue()? where AwfulSettings.shared().embedTweets:
            renderView.embedTweets()
            
        default:
            break
        }
    }
    
    // MARK: Actions
    
    @objc private func didTapReplyButtonItem(_ sender: UIBarButtonItem) {
        let actionSheet = UIAlertController.makeActionSheet()
        
        actionSheet.addActionWithTitle(LocalizedString("private-message.action-reply")) {
            ForumsClient.shared.quoteBBcodeContents(of: self.privateMessage)
                .done { [weak self] bbcode in
                    guard let privateMessage = self?.privateMessage else { return }
                    let composeVC = MessageComposeViewController(regardingMessage: privateMessage, initialContents: bbcode)
                    composeVC.delegate = self
                    composeVC.restorationIdentifier = "New private message replying to private message"
                    self?.composeVC = composeVC
                    self?.present(composeVC.enclosingNavigationController, animated: true, completion: nil)
                }
                .catch { [weak self] error in
                    self?.present(UIAlertController(title: LocalizedString("private-message.quote-error.title"), error: error), animated: true)
            }
        }
        
        actionSheet.addActionWithTitle(LocalizedString("private-message.action-forward")) {
            ForumsClient.shared.quoteBBcodeContents(of: self.privateMessage)
                .done { [weak self] bbcode in
                    guard let privateMessage = self?.privateMessage else { return }
                    let composeVC = MessageComposeViewController(forwardingMessage: privateMessage, initialContents: bbcode)
                    composeVC.delegate = self
                    composeVC.restorationIdentifier = "New private message forwarding private message"
                    self?.composeVC = composeVC
                    self?.present(composeVC.enclosingNavigationController, animated: true, completion: nil)
                }
                .catch { [weak self] error in
                    self?.present(UIAlertController(title: LocalizedString("private-message.quote-error.title"), error: error), animated: true)
            }
        }
        
        actionSheet.addCancelActionWithHandler(nil)
        present(actionSheet, animated: true, completion: nil)
        
        if let popover = actionSheet.popoverPresentationController {
            popover.barButtonItem = sender
        }
    }
    
    @objc private func didLongPressWebView(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }

        renderView.interestingElements(at: sender.location(in: renderView)).done { elements in
            _ = URLMenuPresenter.presentInterestingElements(elements, from: self, renderView: self.renderView)
        }
    }
    
    private func showUserActions(from rect: CGRect) {
        guard let user = privateMessage.from else { return }
        
        func present(_ viewController: UIViewController) {
            if UIDevice.current.userInterfaceIdiom == .pad {
                self.present(viewController.enclosingNavigationController, animated: true, completion: nil)
            } else {
                self.navigationController?.pushViewController(viewController, animated: true)
            }
        }
        
        renderView.unionFrameOfElements(matchingSelector: ".avatar, .nameanddate").done { rect in
            let actionVC = InAppActionViewController()
            actionVC.items = [
                IconActionItem(.userProfile, block: {
                    present(ProfileViewController(user: user))
                }),
                IconActionItem(.rapSheet, block: {
                    present(RapSheetViewController(user: user))
                })
            ]
            
            var rect = rect
            if rect.isNull {
                rect = CGRect(origin: .zero, size: CGSize(width: self.renderView.bounds.width, height: 1))
            }
            
            actionVC.popoverPositioningBlock = { sourceRect, sourceView in
                sourceRect.pointee = rect
                sourceView.pointee = self.renderView
            }
            
            self.present(actionVC, animated: true)
        }
    }
    
    // MARK: Handoff
    
    private func configureUserActivity() {
        guard AwfulSettings.shared().handoffEnabled else { return }
        userActivity = NSUserActivity(activityType: Handoff.ActivityType.readingMessage)
        userActivity?.needsSave = true
    }
    
    override func updateUserActivityState(_ activity: NSUserActivity) {
        activity.route = .message(id: privateMessage.messageID)
        activity.title = {
            if let subject = privateMessage.subject, !subject.isEmpty {
                return subject
            } else {
                return LocalizedString("handoff.message-title")
            }
        }()

        Log.d("handoff activity set: \(activity.activityType) with \(activity.userInfo ?? [:])")
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        renderView.frame = CGRect(origin: .zero, size: view.bounds.size)
        renderView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(renderView, at: 0)
        
        renderView.registerMessage(RenderView.BuiltInMessage.DidRender.self)
        renderView.registerMessage(RenderView.BuiltInMessage.DidTapAuthorHeader.self)
        renderView.registerMessage(RenderView.BuiltInMessage.DidFinishLoadingTweets.self)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPressWebView))
        longPress.delegate = self
        renderView.addGestureRecognizer(longPress)
        
        if privateMessage.innerHTML == nil || privateMessage.innerHTML?.isEmpty == true || privateMessage.from == nil {
            let loadingView = LoadingView.loadingViewWithTheme(theme)
            self.loadingView = loadingView
            view.addSubview(loadingView)

            ForumsClient.shared.readPrivateMessage(identifiedBy: privateMessage.objectKey)
                .done { [weak self] message in
                    self?.title = message.subject

                    if message.seen == false {
                        message.seen = true
                        
                        try message.managedObjectContext?.save()
                    }
                }
                .catch { [weak self] error in
                    self?.title = ""
                }
                .finally { [weak self] in
                    self?.renderMessage()
                    self?.userActivity?.needsSave = true
            }
        } else {
            renderMessage()
        }
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        if didRender, let css = theme["postsViewCSS"] as String? {
            renderView.setThemeStylesheet(css)
        }
        
        loadingView?.tintColor = theme["backgroundColor"]
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        configureUserActivity()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        userActivity = nil
    }
    
    private enum CodingKey {
        static let composeViewController = "AwfulComposeViewController"
        static let message = "MessageKey"
        static let scrollFracton = "AwfulScrollFraction"
    }
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        
        coder.encode(privateMessage.objectKey, forKey: CodingKey.message)
        coder.encode(composeVC, forKey: CodingKey.composeViewController)
        coder.encode(Float(renderView.scrollView.fractionalContentOffset.y), forKey: CodingKey.scrollFracton)
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        
        composeVC = coder.decodeObject(of: MessageComposeViewController.self, forKey: CodingKey.composeViewController)
        composeVC?.delegate = self
        
        fractionalContentOffsetOnLoad = CGFloat(coder.decodeFloat(forKey: CodingKey.scrollFracton))
    }
    
    // MARK: Gunk
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension MessageViewController: ComposeTextViewControllerDelegate {
    func composeTextViewController(_ composeController: ComposeTextViewController, didFinishWithSuccessfulSubmission success: Bool, shouldKeepDraft: Bool) {
        dismiss(animated: true, completion: nil)
        
        composeVC = nil
    }
}

extension MessageViewController: RenderViewDelegate {
    func didReceive(message: RenderViewMessage, in view: RenderView) {
        switch message {
        case is RenderView.BuiltInMessage.DidRender:
            if fractionalContentOffsetOnLoad > 0 {
                renderView.scrollToFractionalOffset(CGPoint(x: 0, y: fractionalContentOffsetOnLoad))
            }
            
            loadingView?.removeFromSuperview()
            loadingView = nil
            
            if AwfulSettings.shared().embedTweets {
                renderView.embedTweets()
            }
            
        case is RenderView.BuiltInMessage.DidFinishLoadingTweets:
            if fractionalContentOffsetOnLoad > 0 {
                renderView.scrollToFractionalOffset(CGPoint(x: 0, y: fractionalContentOffsetOnLoad))
            }
            
        case let didTapHeader as RenderView.BuiltInMessage.DidTapAuthorHeader:
            showUserActions(from: didTapHeader.frame)
            
        default:
            Log.w("ignoring unexpected message \(message)")
        }
    }
    
    func didTapLink(to url: URL, in view: RenderView) {
        if let route = try? AwfulRoute(url) {
            AppDelegate.instance.open(route: route)
        }
        else if url.opensInBrowser {
            URLMenuPresenter(linkURL: url).presentInDefaultBrowser(fromViewController: self)
        }
        else {
            UIApplication.shared.openURL(url)
        }
    }
}

extension MessageViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}

extension MessageViewController: UIViewControllerRestoration {
    static func viewController(withRestorationIdentifierPath identifierComponents: [String], coder: NSCoder) -> UIViewController? {
        guard let messageKey = coder.decodeObject(of: PrivateMessageKey.self, forKey: CodingKey.message) else {
            return nil
        }
        
        let context = AppDelegate.instance.managedObjectContext
        guard let privateMessage = PrivateMessage.objectForKey(objectKey: messageKey, inManagedObjectContext: context) as? PrivateMessage else {
            return nil
        }
        
        let messageVC = self.init(privateMessage: privateMessage)
        messageVC.restorationIdentifier = identifierComponents.last
        return messageVC
    }
}
