//  TextAttachment.swift
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Photos
import UIKit

/**
    An enhanced text attachment that:
 
    * Negotiates reasonable image bounds with its text view.
    * Properly populates the image property after UIKit state resotration.
    * Uses the Photos framework for thumbnailing when possible.
 */
final class TextAttachment: NSTextAttachment {
    let assetURL: NSURL?
    
    init(image: UIImage, assetURL: NSURL?) {
        self.assetURL = assetURL
        super.init(data: nil, ofType: nil)
        
        self.image = image
    }
    
    required init?(coder: NSCoder) {
        assetURL = coder.decodeObjectForKey(assetURLKey) as! NSURL?
        super.init(coder: coder)
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        super.encodeWithCoder(coder)
        
        coder.encodeObject(assetURL, forKey: assetURLKey)
    }
    
    override var image: UIImage? {
        get {
            if let image = super.image {
                return image
            }
            
            guard let data = contents ?? fileWrapper?.regularFileContents else { return nil }
            let image = UIImage(data: data)
            self.image = image
            return image
        }
        set {
            super.image = newValue
            _thumbnailImage = nil
        }
    }
    
    private var _thumbnailImage: UIImage?
    var thumbnailImage: UIImage? {
        if let thumbnail = _thumbnailImage { return thumbnail }
        guard let image = self.image else { return nil }
        let thumbnailSize = appropriateThumbnailSize(imageSize: image.size)
        if image.size == thumbnailSize { return image }
        
        if let
            assetURL = assetURL,
            let asset = PHAsset.fetchAssetsWithALAssetURLs([assetURL], options: nil).firstObject as? PHAsset
        {
            let options = PHImageRequestOptions()
            options.synchronous = true
            options.resizeMode = .Exact
            PHImageManager.defaultManager().requestImageForAsset(asset, targetSize: thumbnailSize, contentMode: .AspectFit, options: options, resultHandler: { (image, info) in
                self._thumbnailImage = image
            })
        }
        if let thumbnail = _thumbnailImage { return thumbnail }
        
        _thumbnailImage = image.thumbnail(thumbnailSize)
        return _thumbnailImage
    }
    
    override func attachmentBoundsForTextContainer(textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        let size = thumbnailImage?.size ?? .zero
        return CGRect(origin: .zero, size: size)
    }
    
    override func imageForBounds(imageBounds: CGRect, textContainer: NSTextContainer?, characterIndex: Int) -> UIImage? {
        return thumbnailImage
    }
}

private let assetURLKey = "AwfulAssetURL"

private func appropriateThumbnailSize(imageSize: CGSize) -> CGSize {
    let threshold = TextAttachment.requiresThumbnailImageSize
    let widthRatio = imageSize.width / threshold.width
    let heightRatio = imageSize.height / threshold.height
    let screenRatio = imageSize.width / (UIScreen.mainScreen().bounds.width - 8)
    let ratio = max(widthRatio, heightRatio, screenRatio)
    
    if ratio <= 1 { return imageSize }
    return CGSize(width: floor(imageSize.width / ratio), height: floor(imageSize.height / ratio))
}

private extension UIImage {
    func thumbnail(targetSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(targetSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        drawInRect(CGRect(origin: .zero, size: targetSize))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

// This is only on a class (and then only computed) for Objective-C bridging.
extension TextAttachment {
    static var requiresThumbnailImageSize: CGSize {
        return CGSize(width: 800, height: 600)
    }
}
