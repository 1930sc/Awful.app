//
//  ForumListDataSource.swift
//  Awful
//
//  Created by Nolan Waite on 2017-12-03.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import AwfulCore
import CoreData
import UIKit

final class ForumListDataSource: NSObject {
    private let announcementsController: NSFetchedResultsController<Announcement>
    private let favoriteForumsController: NSFetchedResultsController<ForumMetadata>
    private let forumsController: NSFetchedResultsController<Forum>
    private let tableView: UITableView
    
    init(managedObjectContext: NSManagedObjectContext, tableView: UITableView) throws {
        let announcementsRequest = NSFetchRequest<Announcement>(entityName: Announcement.entityName())
        announcementsRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(Announcement.listIndex), ascending: true)]
        announcementsController = NSFetchedResultsController(
            fetchRequest: announcementsRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        let favoriteForumsRequest = NSFetchRequest<ForumMetadata>(entityName: ForumMetadata.entityName())
        favoriteForumsRequest.predicate = NSPredicate(format: "%K == YES", #keyPath(ForumMetadata.favorite))
        favoriteForumsRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(ForumMetadata.favoriteIndex), ascending: true)]
        favoriteForumsController = NSFetchedResultsController(
            fetchRequest: favoriteForumsRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        let forumsRequest = NSFetchRequest<Forum>(entityName: Forum.entityName())
        forumsRequest.predicate = NSPredicate(format: "%K == YES", #keyPath(Forum.metadata.visibleInForumList))
        forumsRequest.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(Forum.group.index), ascending: true), // section
            NSSortDescriptor(key: #keyPath(Forum.index), ascending: true)]
        forumsController = NSFetchedResultsController(
            fetchRequest: forumsRequest,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: #keyPath(Forum.group.sectionIdentifier),
            cacheName: nil)
        
        self.tableView = tableView
        super.init()
        
        try announcementsController.performFetch()
        try favoriteForumsController.performFetch()
        try forumsController.performFetch()
        
        tableView.dataSource = self
        tableView.register(UINib(nibName: ForumTableViewCell.nibName, bundle: Bundle(for: ForumTableViewCell.self)), forCellReuseIdentifier: ForumTableViewCell.identifier)
        
        announcementsController.delegate = self
        favoriteForumsController.delegate = self
        forumsController.delegate = self
    }
    
    private var resultsControllers: [NSFetchedResultsController<NSFetchRequestResult>] {
        return [announcementsController as! NSFetchedResultsController<NSFetchRequestResult>,
                favoriteForumsController as! NSFetchedResultsController<NSFetchRequestResult>,
                forumsController as! NSFetchedResultsController<NSFetchRequestResult>]
    }
    
    private func controllerAtGlobalSection(_ globalSection: Int) -> (controller: NSFetchedResultsController<NSFetchRequestResult>, localSection: Int) {
        var section = globalSection
        for controller in resultsControllers {
            guard let sections = controller.sections else { continue }
            if section < sections.count {
                return (controller: controller, localSection: section)
            }
            section -= sections.count
        }
        
        fatalError("section index out of bounds: \(section)")
    }
}

extension ForumListDataSource {
    func forum(at indexPath: IndexPath) -> Forum? {
        let (controller, localSection: section) = controllerAtGlobalSection(indexPath.section)
        switch controller.object(at: IndexPath(row: indexPath.row, section: section)) {
        case is Announcement:
            return nil
            
        case let forum as Forum:
            return forum
            
        case let metadata as ForumMetadata:
            return metadata.forum
            
        default:
            fatalError("unknown object type in forum list")
        }
    }
}

extension ForumListDataSource: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        // TODO: more fine-grained than this
        tableView.reloadData()
    }
}

extension ForumListDataSource: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return resultsControllers
            .flatMap { $0.sections?.count }
            .reduce(0, +)
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let (controller: controller, localSection: localSection) = controllerAtGlobalSection(section)
        if controller === announcementsController {
            return LocalizedString("forums-list.announcements-section-title")
        }
        else if controller === favoriteForumsController {
            return LocalizedString("forums-list.favorite-forums.section-title")
        }
        else if controller === forumsController {
            guard let sections = controller.sections else {
                fatalError("something's wrong with the fetched results controller")
            }
            
            let sectionIdentifier = sections[localSection].name
            return String(sectionIdentifier.dropFirst(ForumGroup.sectionIdentifierIndexLength + 1))
        }
        else {
            fatalError("unknown results controller \(controller)")
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let (controller: controller, localSection: localSection) = controllerAtGlobalSection(section)
        return controller.sections?[localSection].numberOfObjects ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let (controller: controller, localSection: localSection) = controllerAtGlobalSection(indexPath.section)
        guard let sections = controller.sections else {
            fatalError("results controller isn't set up")
        }
        let item = controller.object(at: IndexPath(row: indexPath.row, section: localSection))
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ForumTableViewCell.identifier, for: indexPath) as? ForumTableViewCell else {
            fatalError("expected a ForumTableViewCell")
        }
        
        let showSeparator = indexPath.row + 1 < sections[localSection].numberOfObjects
        let viewModel: ForumTableViewCell.ViewModel
        if controller === announcementsController {
            guard let announcement = item as? Announcement else {
                fatalError("expected an Announcement from the announcement results controller")
            }
            viewModel = ForumTableViewCell.ViewModel(
                favorite: announcement.hasBeenSeen ? .hidden : .on,
                name: announcement.title,
                canExpand: .hidden,
                childSubforumCount: 0,
                indentationLevel: 0,
                showSeparator: showSeparator)
        }
        else if controller === favoriteForumsController {
            guard let metadata = item as? ForumMetadata else {
                fatalError("expected a ForumMetadata from the favorite forum results controller")
            }
            viewModel = ForumTableViewCell.ViewModel(
                favorite: .on,
                name: metadata.forum.name ?? "",
                canExpand: .hidden,
                childSubforumCount: 0,
                indentationLevel: 0,
                showSeparator: showSeparator)
        }
        else if controller === forumsController {
            guard let forum = item as? Forum else {
                fatalError("expected a Forum from the forum results controller")
            }
            viewModel = ForumTableViewCell.ViewModel(
                favorite: forum.metadata.favorite ? .hidden : .off,
                name: forum.name ?? "",
                canExpand: {
                    if forum.childForums.isEmpty {
                        return .hidden
                    }
                    else if forum.metadata.showsChildrenInForumList {
                        return .on
                    }
                    else {
                        return .off
                    }
                }(),
                childSubforumCount: forum.childForums.count,
                indentationLevel: forum.ancestors.map { _ in 1 }.reduce(0, +),
                showSeparator: showSeparator)
        }
        else {
            fatalError("unknown results controller \(controller)")
        }
        
        cell.viewModel = viewModel
        return cell
    }
}

// TODO: allow deleting/reordering favorites
// TODO: size and theme section headers
// TODO: non-sticky headers?
