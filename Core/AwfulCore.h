//  AwfulCore.h
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;

FOUNDATION_EXPORT double AwfulCoreVersionNumber;
FOUNDATION_EXPORT const unsigned char AwfulCoreVersionString[];

// Private bits (so Swift can call the methods)
#import <AwfulCore/AwfulForumHierarchyScraper.h>
#import <AwfulCore/AwfulPostScraper.h>
#import <AwfulCore/AwfulPostsPageScraper.h>
#import <AwfulCore/AwfulScanner.h>
#import <AwfulCore/AwfulThreadListScraper.h>
#import <AwfulCore/AwfulUnreadPrivateMessageCountScraper.h>
#import <AwfulCore/LepersColonyPageScraper.h>
#import <AwfulCore/NSString+Undeprecation.h>
#import <AwfulCore/PrivateMessageFolderScraper.h>
#import <AwfulCore/PrivateMessageScraper.h>
#import <AwfulCore/ProfileScraper.h>

// Model
#import <AwfulCore/AwfulThreadPage.h>

// Scraping
#import <AwfulCore/AwfulForm.h>

// Networking
#import <AwfulCore/AwfulForumsClient.h>
