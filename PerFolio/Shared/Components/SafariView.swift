import SwiftUI
import SafariServices

/// SwiftUI wrapper for SFSafariViewController
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    var onDismiss: (() -> Void)?
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        config.barCollapsingEnabled = true
        
        let safari = SFSafariViewController(url: url, configuration: config)
        safari.preferredControlTintColor = UIColor(red: 0.816, green: 0.690, blue: 0.439, alpha: 1.0) // #D0B070
        safari.preferredBarTintColor = UIColor(red: 0.114, green: 0.114, blue: 0.114, alpha: 1.0) // #1D1D1D
        safari.dismissButtonStyle = .close
        safari.delegate = context.coordinator
        
        return safari
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }
    
    class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let onDismiss: (() -> Void)?
        
        init(onDismiss: (() -> Void)?) {
            self.onDismiss = onDismiss
        }
        
        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            onDismiss?()
        }
    }
}

