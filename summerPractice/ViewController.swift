//
//  ViewController.swift
//  summerPractice
//
//  Created by Ильмир Шарафутдинов on 24.07.2025.
//

import UIKit
import MediaPipeTasksVision
import SwiftUI

class ViewController: UIViewController {
    private let button = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        
        button.setTitle("Открыть камеру", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(openCamera), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 200),
            button.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    @objc private func openCamera() {
        let cameraView = CameraView()
        let hostingController = UIHostingController(rootView: cameraView)
        hostingController.modalPresentationStyle = .fullScreen
        present(hostingController, animated: true)
    }
}
