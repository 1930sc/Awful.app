//  CoreGraphics.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreGraphics

extension CGContext {
    func addLine(point: CGPoint) {
        CGContextAddLineToPoint(self, point.x, point.y)
    }
    
    func clip(rect: CGRect) {
        CGContextClipToRect(self, rect)
    }
    
    func fillPath() {
        CGContextFillPath(self)
    }
    
    func fillRect(rect: CGRect) {
        CGContextFillRect(self, rect)
    }

    func move(point: CGPoint) {
        CGContextMoveToPoint(self, point.x, point.y)
    }
    
    func setFillColor(color: CGColor) {
        CGContextSetFillColorWithColor(self, color)
    }
    
    func setShadow(offset offset: CGSize, blur: CGFloat, color: CGColor) {
        CGContextSetShadowWithColor(self, offset, blur, color)
    }
    
    func withGState(@noescape block: () -> Void) {
        CGContextSaveGState(self)
        block()
        CGContextRestoreGState(self)
    }
}
