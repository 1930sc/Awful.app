//
//  AppIconCell.swift
//  Awful
//
//  Created by Liam Westby on 9/24/17.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import UIKit

final class AppIconCell: UICollectionViewCell {
    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var isSelectedIcon: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()

        imageView.layer.mask = makeSquircleMask()
    }

    func configure(image: UIImage?, isCurrentlySelectedIcon: Bool) {
        imageView.image = image
        isSelectedIcon.isHidden = !isCurrentlySelectedIcon
    }
}

private func makeSquircleMask() -> CALayer {
    let shape = CAShapeLayer()
    shape.path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 60, height: 60), cornerRadius: 13).cgPath
    shape.fillColor = UIColor.black.cgColor
    return shape
}
