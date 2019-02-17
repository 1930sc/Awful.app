//  MustacheRepository.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Mustache

/**
 Mustache templates in the main bundle.

 These templates are rendered with some extra context, so there's no need to include these yourself:

 - baseURL
 - fontScalePercentage
 - format (a dictionary with various formatters; use as e.g. `{{ format.postDate(post.date) }}`)
    - announcementDate
    - postDate
    - regdate
    - sentDate
 - javascriptEscape
 - userInterfaceIdiom (either `ipad` or `iphone`)
 - version (e.g. `3.35`)
 */
struct MustacheTemplate {

    // Known templates:
    static let acknowledgements = MustacheTemplate(name: "Acknowledgements")
    static let announcement = MustacheTemplate(name: "Announcement")
    static let post = MustacheTemplate(name: "Post")
    static let postPreview = MustacheTemplate(name: "PostPreview")
    static let postsView = MustacheTemplate(name: "PostsView")
    static let privateMessage = MustacheTemplate(name: "PrivateMessage")
    static let profile = MustacheTemplate(name: "Profile")

    /// Renders a known template (see `MustacheRepository.swift` for a list of known templates). `value` might be a dictionary or a `MustacheBoxable`.
    static func render(_ template: MustacheTemplate, value: Any?) throws -> String {
        let template = try repository.template(named: template.name)
        return try template.render(value)
    }

    private let name: String
}

private let repository: TemplateRepository = {
    let repo = TemplateRepository(bundle: .main)

    let fontScale: RenderFunction = { info in
        let scale = UserDefaults.standard.fontScale
        switch info.tag.type {
        case .variable:
            return Rendering("\(scale)")
        case .section:
            if scale == 100 {
                return Rendering("")
            } else {
                return try info.tag.render(info.context)
            }
        }

    }

    repo.configuration.extendBaseContext([
        "baseURL": ForumsClient.shared.baseURL as Any,
        "fontScalePercentage": fontScale,
        "format": [
            "announcementDate": DateFormatter.announcementDateFormatter,
            "postDate": DateFormatter.postDateFormatter,
            "regdate": DateFormatter.regDateFormatter,
            "sentDate": DateFormatter.postDateFormatter],
        "javascriptEscape": StandardLibrary.javascriptEscape,
        "userInterfaceIdiom": { () -> String in
            switch UIDevice.current.userInterfaceIdiom {
            case .pad:
                return "ipad"
            default:
                return "iphone"
            }
        }(),
        "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String])
    return repo
}()
