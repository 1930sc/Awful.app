//  ForumsTableViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData
import UIKit

final class ForumsTableViewController: TableViewController {
    let managedObjectContext: NSManagedObjectContext
//    fileprivate var dataSource: ForumTableViewDataSource!
    private var dataSource: ForumListDataSource!
    private var unreadAnnouncementCountObserver: ManagedObjectCountObserver!
    
    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        super.init(style: .plain)
        
        title = "Forums"
        tabBarItem.image = UIImage(named: "forum-list")
        tabBarItem.selectedImage = UIImage(named: "forum-list-filled")

        unreadAnnouncementCountObserver = ManagedObjectCountObserver(
            context: managedObjectContext,
            entityName: Announcement.entityName(),
            predicate: NSPredicate(format: "%K == NO", #keyPath(Announcement.hasBeenSeen)),
            didChange: { [weak self] unreadCount in
                self?.updateBadgeValue(unreadCount) })
        updateBadgeValue(unreadAnnouncementCountObserver.count)
        
        NotificationCenter.default.addObserver(self, selector: #selector(didChangeSettings), name: .AwfulSettingsDidChange, object: AwfulSettings.shared())
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func refreshIfNecessary() {
//        if RefreshMinder.sharedMinder.shouldRefresh(.forumList) || dataSource.isEmpty {
//            refresh()
//        }
    }
    
    fileprivate func refresh() {
        ForumsClient.shared.taxonomizeForums()
            .then { (forums) -> Void in
                RefreshMinder.sharedMinder.didRefresh(.forumList)
                self.migrateFavoriteForumsFromSettings()
            }
            .always { self.stopAnimatingPullToRefresh() }
    }
    
    fileprivate func migrateFavoriteForumsFromSettings() {
        // In Awful 3.2 favorite forums moved from AwfulSettings (i.e. NSUserDefaults) to the ForumMetadata entity in Core Data.
        if let forumIDs = AwfulSettings.shared().favoriteForums as! [String]? {
            AwfulSettings.shared().favoriteForums = nil
            let metadatas = ForumMetadata.metadataForForumsWithIDs(forumIDs: forumIDs, inManagedObjectContext: managedObjectContext)
            for (i, metadata) in metadatas.enumerated() {
                metadata.favoriteIndex = Int32(i)
                metadata.favorite = true
            }
            do {
                try managedObjectContext.save()
            }
            catch {
                fatalError("error saving: \(error)")
            }
        }
    }
    
    @objc private func didChangeSettings(_ notification: Notification) {
        if
            let settingsKey = notification.userInfo?[AwfulSettingsDidChangeSettingKey] as? String,
            settingsKey == AwfulSettingsKeys.showUnreadAnnouncementsBadge.takeUnretainedValue() as String
        {
            updateBadgeValue(unreadAnnouncementCountObserver.count)
        }
    }
    
    private func updateBadgeValue(_ unreadCount: Int) {
        tabBarItem?.badgeValue = {
            guard AwfulSettings.shared().showUnreadAnnouncementsBadge else { return nil }
            
            return unreadCount > 0
                ? NumberFormatter.localizedString(from: unreadCount as NSNumber, number: .none)
                : nil
        }()
    }
    
    func openForum(_ forum: Forum, animated: Bool) {
        let threadList = ThreadsTableViewController(forum: forum)
        threadList.restorationClass = ThreadsTableViewController.self
        threadList.restorationIdentifier = "Thread"
        navigationController?.pushViewController(threadList, animated: animated)
    }

    func openAnnouncement(_ announcement: Announcement) {
        let vc = AnnouncementViewController(announcement: announcement)
        vc.restorationIdentifier = "Announcement"
        showDetailViewController(vc, sender: self)
    }
    
    fileprivate func updateEditButtonPresence(animated: Bool) {
        // TODO: move this to a managed object context observer and leave the data source out of it!
        navigationItem.setRightBarButton(dataSource.hasFavorites ? editButtonItem : nil, animated: animated)
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        tableView.register(UINib(nibName: ForumTableViewCell.nibName, bundle: nil), forCellReuseIdentifier: ForumTableViewCell.identifier)
//        tableView.register(UITableViewCell.self, forCellReuseIdentifier: ForumTableViewDataSource.headerReuseIdentifier)
        
        tableView.estimatedRowHeight = ForumTableViewCell.estimatedRowHeight
        tableView.separatorStyle = .none
        
//        let cellConfigurator: (ForumTableViewCell, ForumTableViewCell.ViewModel) -> Void = { [weak self] cell, viewModel in
//            cell.viewModel = viewModel
//            cell.starButtonAction = self?.didTapStarButton
//            cell.disclosureButtonAction = self?.didTapDisclosureButton
//
//            guard let theme = self?.theme else { return }
//            cell.themeData = ForumTableViewCell.ThemeData(theme)
//        }
//        let headerThemer: (UITableViewCell) -> Void = { [weak self] cell in
//            guard let theme = self?.theme else { return }
//            cell.textLabel?.textColor = theme["listHeaderTextColor"]
//            cell.backgroundColor = theme["listHeaderBackgroundColor"]
//            cell.selectedBackgroundColor = theme["listHeaderBackgroundColor"]
//        }
//        dataSource = ForumTableViewDataSource(tableView: tableView, managedObjectContext: managedObjectContext, cellConfigurator: cellConfigurator, headerThemer: headerThemer)
        do {
            dataSource = try ForumListDataSource(managedObjectContext: managedObjectContext, tableView: tableView)
        }
        catch {
            fatalError("could not initialize forum list data source: \(error)")
        }
//        tableView.dataSource = dataSource
        
//        dataSource.didReload = { [weak self] in
//            self?.updateEditButtonPresence(animated: false)
//
//            if self?.isEditing == true && self?.dataSource.hasFavorites == false {
//                DispatchQueue.main.async {
//                    // The docs say not to call this from an implementation of UITableViewDataSource.tableView(_:commitEditingStyle:forRowAtIndexPath:), but if you must, do a delayed perform.
//                    self?.setEditing(false, animated: true)
//                }
//            }
//        }
        
        updateEditButtonPresence(animated: false)
        
        pullToRefreshBlock = { [weak self] in
            self?.refresh()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshIfNecessary()
    }
    
    // MARK: Actions
    
    private func didTapStarButton(in cell: ForumTableViewCell) {
        guard
            let indexPath = tableView.indexPath(for: cell),
            let forum = dataSource.item(at: indexPath) as? Forum
            else { return }

        if forum.metadata.favorite {
            forum.metadata.favorite = false
        }
        else {
            forum.metadata.favorite = true
            forum.metadata.favoriteIndex = dataSource.nextFavoriteIndex
        }
        forum.tickleForFetchedResultsController()
        
        try! forum.managedObjectContext!.save()
    }

    private func didTapDisclosureButton(in cell: ForumTableViewCell) {
        guard
            let indexPath = tableView.indexPath(for: cell),
            let forum = dataSource.item(at: indexPath) as? Forum
            else { return }

        if forum.metadata.showsChildrenInForumList {
            forum.collapse()
        }
        else {
            forum.expand()
        }
        
        try! forum.managedObjectContext!.save()
    }
}

extension ForumsTableViewController {
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if tableView.dataSource?.tableView(tableView, numberOfRowsInSection: section) == 0 {
            return 0
        }
        else {
            return UITableViewAutomaticDimension
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? ForumTableViewCell {
            cell.disclosureButtonAction = { [weak self] cell in
                self?.didTapDisclosureButton(in: cell)
            }
            
            cell.starButtonAction = { [weak self] cell in
                self?.didTapStarButton(in: cell)
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch dataSource.item(at: indexPath) {
        case let announcement as Announcement:
            openAnnouncement(announcement)

        case let forum as Forum:
            openForum(forum, animated: true)

        default:
            assertionFailure("unknown object type in forums list")
        }
    }

//    override func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath toIndexPath: IndexPath) -> IndexPath {
//        guard
//            let firstFavoriteIndex = dataSource.firstFavoriteIndex,
//            let lastFavoriteIndex = dataSource.lastFavoriteIndex
//            else { fatalError("asking for target index path for non-favorite") }
//        let targetRow = max(firstFavoriteIndex, min(toIndexPath.row, lastFavoriteIndex))
//        return IndexPath(row: targetRow, section: 0)
//    }
}

//extension ForumTableViewCell.ThemeData {
//    init(_ theme: Theme) {
//        nameColor = theme["listTextColor"]!
//        backgroundColor = theme["listBackgroundColor"]!
//        selectedBackgroundColor = theme["listSelectedBackgroundColor"]!
//        separatorColor = theme["listSeparatorColor"]!
//    }
//}

