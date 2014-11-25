//  MessageFolderScrapingTests.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import XCTest
import Awful

class MessageFolderScrapingTests: ScrapingTestCase {
    override class func scraperClass() -> AnyClass {
        return PrivateMessageFolderScraper.self
    }

    func testInbox() {
        let scraper = scrapeFixtureNamed("private-list") as PrivateMessageFolderScraper
        let messages = scraper.messages
        XCTAssertTrue(messages.count == 4)
        XCTAssertEqual(messages.count, fetchAll(PrivateMessage.self, inContext: managedObjectContext).count)
        
        let tagged = fetchOne(PrivateMessage.self, inContext: managedObjectContext, matchingPredicate: NSPredicate(format: "rawFromUsername = 'CamH'"))!
        XCTAssertEqual(tagged.messageID, "4549686")
        XCTAssertEqual(tagged.subject!, "Re: Awful app etc.")
        XCTAssertEqual(tagged.sentDate!.timeIntervalSince1970, 1348778940)
        XCTAssertEqual(tagged.threadTag!.imageName!, "sex")
        XCTAssertTrue(tagged.replied)
        XCTAssertTrue(tagged.seen)
        XCTAssertFalse(tagged.forwarded)
    }
}
