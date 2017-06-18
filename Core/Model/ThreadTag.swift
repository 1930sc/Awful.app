//  ThreadTag.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@objc(ThreadTag)
public class ThreadTag: AwfulManagedObject {
    @NSManaged public var imageName: String?
    @NSManaged public var threadTagID: String?
    
    @NSManaged var forums: NSMutableSet /* AwfulForum via threadTags */
    @NSManaged var messages: NSMutableSet /* PrivateMessage */
    @NSManaged var secondaryForums: NSMutableSet /* AwfulForum via secondaryThreadTags */
    @NSManaged var secondaryThreads: NSMutableSet /* AwfulThread via secondaryThreadTag */
    @NSManaged var threads: NSMutableSet /* AwfulThread via threadTag */
}

extension ThreadTag {
    func setURL(url: URL) {
        imageName = ThreadTag.imageName(from: url)
    }

    public static func imageName(from url: URL) -> String {
        return url.deletingPathExtension().lastPathComponent
    }
}

@objc(ThreadTagKey)
public final class ThreadTagKey: AwfulObjectKey {
    public let imageName: String?
    public let threadTagID: String?
    
    public init(imageName: String!, threadTagID: String!) {
        let imageName = nilIfEmpty(s: imageName)
        let threadTagID = nilIfEmpty(s: threadTagID)
        precondition(imageName != nil || threadTagID != nil)
        
        self.imageName = imageName
        self.threadTagID = threadTagID
        super.init(entityName: ThreadTag.entityName())
    }
    
    public convenience init(imageURL: URL, threadTagID: String?) {
        self.init(imageName: ThreadTag.imageName(from: imageURL), threadTagID: threadTagID)
    }
    
    public required init?(coder: NSCoder) {
        imageName = coder.decodeObject(forKey: imageNameKey) as! String?
        threadTagID = coder.decodeObject(forKey: threadTagIDKey) as! String?
        super.init(coder: coder)
    }
    
    override var keys: [String] {
        return [imageNameKey, threadTagIDKey]
    }
}
private let imageNameKey = "imageName"
private let threadTagIDKey = "threadTagID"

extension ThreadTag {
    public override var objectKey: ThreadTagKey {
        return ThreadTagKey(imageName: imageName, threadTagID: threadTagID)
    }
}
