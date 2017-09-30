//
//  AppIconPickerCollectionViewLayout.swift
//  Awful
//
//  Created by Liam Westby on 9/23/17.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import UIKit

final class AppIconPickerCollectionViewLayout: UICollectionViewFlowLayout {
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        self.scrollDirection = .horizontal
        self.minimumInteritemSpacing = 10
        self.estimatedItemSize = CGSize(width: 70, height: 120)
        self.sectionInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
    }
}
