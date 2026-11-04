import UIKit
import Social
import MobileCoreServices
import Photos

class ShareViewController: UIViewController {
    
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let iconImageView = UIImageView()
    private let closeButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        processSharedItem()
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        
        // Container Card
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = UIColor(red: 0.10, green: 0.12, blue: 0.20, alpha: 0.95)
        containerView.layer.cornerRadius = 20
        containerView.layer.masksToBounds = true
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.cyan.withAlphaComponent(0.3).cgColor
        view.addSubview(containerView)
        
        // App Icon
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.image = UIImage(systemName: "arrow.down.circle.fill")
        iconImageView.tintColor = .cyan
        containerView.addSubview(iconImageView)
        
        // Title
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Quick Save"
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .white
        containerView.addSubview(titleLabel)
        
        // Status
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Đang nhận diện liên kết..."
        statusLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        statusLabel.textColor = UIColor.lightGray
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2
        containerView.addSubview(statusLabel)
        
        // Progress Bar
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = .cyan
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.1)
        progressView.progress = 0.2
        containerView.addSubview(progressView)
        
        // Cancel/Close Button
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("Hủy", for: .normal)
        closeButton.setTitleColor(UIColor.gray, for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        closeButton.addTarget(self, action: #selector(cancelAction), for: .touchUpInside)
        containerView.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 290),
            containerView.heightAnchor.constraint(equalToConstant: 210),
            
            iconImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            iconImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 18),
            iconImageView.widthAnchor.constraint(equalToConstant: 40),
            iconImageView.heightAnchor.constraint(equalToConstant: 40),
            
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 8),
            
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            statusLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            
            progressView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            progressView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            progressView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 14),
            progressView.heightAnchor.constraint(equalToConstant: 4),
            
            closeButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            closeButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 12)
        ])
    }
    
    @objc private func cancelAction() {
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
    
    private func processSharedItem() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            finishWithError("Không nhận được nội dung chia sẻ.")
            return
        }
        
        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                // Kiểm tra nếu là URL
                if provider.hasItemConformingToTypeIdentifier("public.url") {
                    provider.loadItem(forTypeIdentifier: "public.url", options: nil) { [weak self] (item, error) in
                        if let url = item as? URL {
                            self?.startDownloading(urlString: url.absoluteString)
                        }
                    }
                    return
                }
                
                // Kiểm tra nếu là Văn bản có chứa URL
                if provider.hasItemConformingToTypeIdentifier("public.plain-text") {
                    provider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { [weak self] (item, error) in
                        if let text = item as? String {
                            self?.startDownloading(urlString: text)
                        }
                    }
                    return
                }
            }
        }
    }
    
    private func startDownloading(urlString: String) {
        DispatchQueue.main.async {
            self.statusLabel.text = "Đang bóc tách video..."
            self.progressView.setProgress(0.4, animated: true)
        }
        
        VideoDownloaderEngine.shared.processAndDownload(urlString: urlString) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.progressView.setProgress(1.0, animated: true)
                    self?.iconImageView.image = UIImage(systemName: "checkmark.circle.fill")
                    self?.iconImageView.tintColor = .systemGreen
                    self?.statusLabel.textColor = .systemGreen
                    self?.statusLabel.text = "Đã lưu vào Album Ảnh!"
                    self?.closeButton.isHidden = true
                    
                    // Tự động đóng sau 1.5 giây
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                    }
                case .failure(let err):
                    self?.finishWithError(err.localizedDescription)
                }
            }
        }
    }
    
    private func finishWithError(_ message: String) {
        DispatchQueue.main.async {
            self.iconImageView.image = UIImage(systemName: "exclamationmark.triangle.fill")
            self.iconImageView.tintColor = .systemRed
            self.statusLabel.textColor = .systemRed
            self.statusLabel.text = message
            self.closeButton.setTitle("Đóng", for: .normal)
            self.progressView.isHidden = true
        }
    }
}
