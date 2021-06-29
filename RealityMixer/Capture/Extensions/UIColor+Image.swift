//
//  UIColor+Image.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 16/06/2021.
//

import UIKit

extension UIColor {

    func image(size: CGSize) -> UIImage? {
        let frame = CGRect(origin: .zero, size: size)
        UIGraphicsBeginImageContext(size)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }

        context.setFillColor(cgColor)
        context.fill(frame)

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}
