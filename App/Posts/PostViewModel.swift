//  PostViewModel.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Foundation
import HTMLReader
import Mustache

struct PostViewModel: MustacheBoxable {
    private let dict: [String: Any]

    init(_ post: Post) {
        var roles: String {
            guard let author = post.author else { return "" }
            var roles = author.authorClasses ?? ""
            if post.thread?.author == author {
                roles += " op"
            }
            return roles
        }
        var accessibilityRoles: String {
            let spokenRoles = [
                "ik": "internet knight",
                "op": "original poster",
                ]
            return roles
                .components(separatedBy: .whitespacesAndNewlines)
                .map { spokenRoles[$0] ?? $0 }
                .joined(separator: "; ")
        }
        var showAvatars: Bool {
            return AwfulSettings.shared().showAvatars
        }
        var hiddenAvatarURL: URL? {
            return showAvatars ? nil : post.author?.avatarURL
        }
        var htmlContents: String {
            guard let innerHTML = post.innerHTML else { return "" }

            let document = HTMLDocument(string: innerHTML)
            document.removeSpoilerStylingAndEvents()
            document.removeEmptyEditedByParagraphs()
            document.useHTML5VimeoPlayer()
            document.highlightQuotesOfPosts(byUserNamed: AwfulSettings.shared().username)
            document.processImgTags(shouldLinkifyNonSmilies: !AwfulSettings.shared().showImages)
            if !AwfulSettings.shared().autoplayGIFs {
                document.stopGIFAutoplay()
            }
            if post.ignored {
                document.markRevealIgnoredPostLink()
            }
            return document.firstNode(matchingSelector: "body")!.innerHTML
        }
        var visibleAvatarURL: URL? {
            return showAvatars ? post.author?.avatarURL : nil
        }

        dict = [
            "accessibilityRoles": accessibilityRoles,
            "author": [
                "regdate": post.author?.regdate as Any,
                "userID": post.author?.userID as Any,
                "username": post.author?.username as Any],
            "beenSeen": post.beenSeen,
            "hiddenAvatarURL": hiddenAvatarURL as Any,
            "htmlContents": htmlContents,
            "postDate": post.postDate as Any,
            "postID": post.postID,
            "roles": roles,
            "showAvatars": showAvatars,
            "visibleAvatarURL": visibleAvatarURL as Any]
    }

    var mustacheBox: MustacheBox {
        return Box(dict)
    }
}

private extension HTMLDocument {
    func markRevealIgnoredPostLink() {
        guard
            let link = firstNode(matchingSelector: "a[title=\"DON'T DO IT!!\"]"),
            let href = link["href"],
            var components = URLComponents(string: href)
            else { return }
        components.fragment = "awful-ignored"
        guard let replacement = components.url?.absoluteString else { return }
        link["href"] = replacement
    }
}
