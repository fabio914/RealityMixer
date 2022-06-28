//
//  QuickCalibrationViewController.swift
//  RealityMixer
//
//  Created by Fabio de Albuquerque Dela Antonio on 13/07/2021.
//

import UIKit
import ARKit
import AVFoundation
import SwiftSocket
import UIScreenExtension

final class QuickCalibrationViewController: UIViewController {
    weak var delegate: CalibrationViewControllerDelegate?
    private let scaleFactor: Double
    private let client: TCPClient

    @IBOutlet private weak var aligmentWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var aligmentImageView: UIImageView!

    init(client: TCPClient, scaleFactor: Double, delegate: CalibrationViewControllerDelegate?) {
        self.client = client
        self.scaleFactor = scaleFactor
        self.delegate = delegate
        super.init(nibName: String(describing: type(of: self)), bundle: Bundle(for: type(of: self)))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let alignmentImagePixelsWidth: CGFloat = 1000
        let alignmentImagePixelsPerInch: CGFloat = 264
        let pointsPerInch: CGFloat = UIScreen.pointsPerInch ?? 0

        aligmentWidthConstraint.constant = (alignmentImagePixelsWidth/alignmentImagePixelsPerInch) * pointsPerInch
    }
}
