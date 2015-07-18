//  UIKit.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

extension UITextView {
    /// Returns a rectangle that encompasses the current selection in the text view, or nil if there is no selection.
    var selectedRect: CGRect? {
        switch selectedTextRange {
        case .Some(let selection) where selection.empty:
            return caretRectForPosition(selection.end)
        case .Some(let selection):
            let rects = selectionRectsForRange(selection).map { $0.rect }
            if rects.isEmpty {
                return nil
            } else {
                return rects.reduce(CGRect.nullRect) { $0.rectByUnion($1) }
            }
        case .None:
            return nil
        }
    }
}
