//  MessageListViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData
import UIKit

private let Log = Logger.get(level: .debug)

@objc(MessageListViewController)
final class MessageListViewController: TableViewController {

    private var dataSource: MessageListDataSource?
    private let managedObjectContext: NSManagedObjectContext
    private var unreadMessageCountObserver: ManagedObjectCountObserver!
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        super.init(nibName: nil, bundle: nil)
        
        title = LocalizedString("private-message-list.title")
        
        tabBarItem.title = LocalizedString("private-message-tab.title")
        tabBarItem.accessibilityLabel = LocalizedString("private-message-tab.accessibility-label")
        tabBarItem.image = UIImage(named: "pm-icon")
        tabBarItem.selectedImage = UIImage(named: "pm-icon-filled")
        
        let updateBadgeValue = { [weak self] (unreadCount: Int) -> Void in
            self?.tabBarItem?.badgeValue = unreadCount > 0
                ? NumberFormatter.localizedString(from: unreadCount as NSNumber, number: .none)
                : nil
        }
        unreadMessageCountObserver = ManagedObjectCountObserver(
            context: managedObjectContext,
            entityName: PrivateMessage.entityName(),
            predicate: NSPredicate(format: "%K == NO", #keyPath(PrivateMessage.seen)),
            didChange: updateBadgeValue)
        updateBadgeValue(unreadMessageCountObserver.count)
        
        navigationItem.leftBarButtonItem = editButtonItem
        let composeItem = UIBarButtonItem(image: UIImage(named: "compose"), style: .plain, target: self, action: #selector(MessageListViewController.didTapComposeButtonItem(_:)))
        composeItem.accessibilityLabel = LocalizedString("private-message-list.compose-button.accessibility-label")
        navigationItem.rightBarButtonItem = composeItem
        
        NotificationCenter.default.addObserver(self, selector: #selector(settingsDidChange), name: .AwfulSettingsDidChange, object: nil)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeDataSource() -> MessageListDataSource {
        let dataSource = try! MessageListDataSource(
            managedObjectContext: managedObjectContext,
            tableView: tableView,
            showsTag: AwfulSettings.shared().showThreadTags)
        dataSource.deletionDelegate = self
        return dataSource
    }
    
    @objc fileprivate func settingsDidChange(_ notification: Notification) {
        guard let key = notification.userInfo?[AwfulSettingsDidChangeSettingKey] as? String else { return }

        if key == AwfulSettingsKeys.showThreadTags.takeUnretainedValue() as String, isViewLoaded {
            dataSource = makeDataSource()
        }
    }
    
    private var composeViewController: MessageComposeViewController?
    
    @objc private func didTapComposeButtonItem(_ sender: UIBarButtonItem) {
        if composeViewController == nil {
            let compose = MessageComposeViewController()
            compose.restorationIdentifier = "New message"
            compose.delegate = self
            composeViewController = compose
        }
        if let compose = composeViewController {
            present(compose.enclosingNavigationController, animated: true, completion: nil)
        }
    }
    
    private func refreshIfNecessary() {
        if !AwfulSettings.shared().canSendPrivateMessages { return }
        
        if tableView.numberOfSections >= 1, tableView.numberOfRows(inSection: 0) == 0 {
            return refresh()
        }
        
        if RefreshMinder.sharedMinder.shouldRefresh(.privateMessagesInbox) {
            return refresh()
        }
    }
    
    @objc private func refresh() {
        startAnimatingPullToRefresh()
        
        _ = ForumsClient.shared.listPrivateMessagesInInbox()
            .then { (messages) -> Void in
                RefreshMinder.sharedMinder.didRefresh(.privateMessagesInbox)
            }
            .catch { [weak self] (error) -> Void in
                guard let sself = self else { return }
                if sself.visible {
                    let alert = UIAlertController(networkError: error)
                    sself.present(alert, animated: true)
                }
            }
            .always { [weak self] in
                self?.stopAnimatingPullToRefresh()
        }
    }
    
    func showMessage(_ message: PrivateMessage) {
        let viewController = MessageViewController(privateMessage: message)
        viewController.restorationIdentifier = "Message"
        showDetailViewController(viewController, sender: self)
    }

    private func deleteMessage(_ message: PrivateMessage) {
        guard let context = message.managedObjectContext else { return }

        Log.d("deleting")
        context.delete(message)

        ForumsClient.shared
            .deletePrivateMessage(message)
            .catch { [weak self] (error) in
                guard let sself = self, sself.visible else { return }
                
                let alert = UIAlertController(title: LocalizedString("private-messages-list.deletion-error.title"), error: error)
                sself.present(alert, animated: true)
        }
    }

    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.estimatedRowHeight = 65
        tableView.separatorStyle = .none

        dataSource = makeDataSource()
        tableView.reloadData()

        pullToRefreshBlock = { [unowned self] in
            self.refresh()
        }
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        composeViewController?.themeDidChange()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        refreshIfNecessary()
    }
}

// MARK: UITableViewDelegate
extension MessageListViewController {
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        super.tableView(tableView, willDisplay: cell, forRowAt: indexPath)
        let cell = cell as! MessageCell
        cell.backgroundColor = theme["listBackgroundColor"]
        cell.senderLabel.textColor = theme["listTextColor"]
        let descriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: UIFontTextStyle.subheadline)
        cell.senderLabel.font = UIFont.boldSystemFont(ofSize: descriptor.pointSize)
        cell.dateLabel.textColor = theme["listTextColor"]
        cell.subjectLabel.textColor = theme["listTextColor"]
        cell.separator.backgroundColor = theme["listSeparatorColor"]
        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = theme["listSelectedBackgroundColor"]
        cell.selectedBackgroundView = selectedBackgroundView
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let message = dataSource!.message(at: indexPath)
        showMessage(message)
    }

    @available(iOS 11.0, *)
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: LocalizedString("table-view.action.delete"), handler: { action, view, completion in
            guard let message = self.dataSource?.message(at: indexPath) else { return }
            self.deleteMessage(message)
            completion(true)
        })
        let config = UISwipeActionsConfiguration(actions: [delete])
        config.performsFirstActionWithFullSwipe = false
        return config
    }
}

extension MessageListViewController: ComposeTextViewControllerDelegate {
    func composeTextViewController(_ composeTextViewController: ComposeTextViewController, didFinishWithSuccessfulSubmission success: Bool, shouldKeepDraft: Bool) {
        dismiss(animated: true, completion: nil)
        if !shouldKeepDraft {
            self.composeViewController = nil
        }
    }
}

extension MessageListViewController {
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        
        coder.encode(composeViewController, forKey: ComposeViewControllerKey)
    }
    
    override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        
        composeViewController = coder.decodeObject(forKey: ComposeViewControllerKey) as! MessageComposeViewController?
        composeViewController?.delegate = self
    }
}

private let ComposeViewControllerKey = "AwfulComposeViewController"

extension MessageListViewController: MessageListDataSourceDeletionDelegate {
    func didDeleteMessage(_ message: PrivateMessage, in dataSource: MessageListDataSource) {
        deleteMessage(message)
    }
}
