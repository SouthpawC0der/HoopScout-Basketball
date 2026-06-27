//
//  SafariView.swift
//  HoopScout
//
//  Lightweight SwiftUI wrapper around SFSafariViewController for presenting
//  external article URLs inside the app.
//

import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let controller = SFSafariViewController(url: url, configuration: config)
        controller.dismissButtonStyle = .done
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}
