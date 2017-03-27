//  ScrapingTestCase.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import XCTest
import AwfulCore
import CoreData

class ScrapingTestCase: XCTestCase {
    var managedObjectContext: NSManagedObjectContext!
    
    fileprivate var storeCoordinator: NSPersistentStoreCoordinator = {
        let modelURL = Bundle(for: AwfulManagedObject.self).url(forResource: "Awful", withExtension: "momd")!
        let model = NSManagedObjectModel(contentsOf: modelURL)!
        return NSPersistentStoreCoordinator(managedObjectModel: model)
        }()
    fileprivate var memoryStore: NSPersistentStore!
    
    class func scraperClass() -> AnyClass {
        fatalError("subclass implementation please")
    }
    
    override func setUp() {
        super.setUp()
        
        // The scraper uses the default time zone. To make the test repeatable, we set a known time zone.
        //TimeZone.default = TimeZone(forSecondsFromGMT: 0)
        do {
            memoryStore = try storeCoordinator.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
        }
        catch {
            fatalError("error adding memory store: \(error)")
        }
        
        managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = storeCoordinator
    }
    
    override func tearDown() {
        managedObjectContext = nil
        do {
            try storeCoordinator.remove(memoryStore)
        }
        catch {
            fatalError("error removing store: \(error)")
        }
        
        super.tearDown()
    }
    
    func scrapeFixtureNamed(_ fixtureName: String) -> AwfulScraper {
        let document = fixtureNamed(fixtureName)
        let scraperClass = type(of: self).scraperClass() as! AwfulScraper.Type
        let scraper = scraperClass.scrape(document, into: managedObjectContext)
        assert(scraper?.error == nil, "error scraping \(scraperClass): \(String(describing: scraper?.error))")
        return scraper!
    }
}
