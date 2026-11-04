import Foundation
import Photos
import UIKit

class VideoDownloaderEngine: ObservableObject {
    static let shared = VideoDownloaderEngine()
    
    @Published var isDownloading = false
    @Published var progress: Float = 0.0
    @Published var statusMessage = ""
    @Published var lastSavedVideoURL: URL?
    
    struct DownloadItem: Identifiable, Codable {
        var id: UUID = UUID()
        var title: String
        var sourceURL: String
        var localFilePath: String
        var date: Date
        var fileSize: Int64
    }
    
    @Published var history: [DownloadItem] = []
    
    init() {
        loadHistory()
    }
    
    // MARK: - Core Download Process
    func processAndDownload(urlString: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let url = extractURL(from: urlString) else {
            completion(.failure(NSError(domain: "QuickSave", code: 400, userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy đường link hợp lệ."])))
            return
        }
        
        DispatchQueue.main.async {
            self.isDownloading = true
            self.progress = 0.1
            self.statusMessage = "Đang phân tích video..."
        }
        
        let absoluteString = url.absoluteString.lowercased()
        
        // 1. TikTok: Bóc tách không logo qua TikWM
        if absoluteString.contains("tiktok.com") {
            downloadTikTok(url: url, completion: completion)
            return
        }
        
        // 2. Facebook (Reels / Video / fb.watch)
        if absoluteString.contains("facebook.com") || absoluteString.contains("fb.watch") {
            downloadFacebook(url: url, completion: completion)
            return
        }
        
        // 3. Link file MP4 trực tiếp
        if absoluteString.hasSuffix(".mp4") || absoluteString.contains(".mp4?") {
            downloadDirectFile(url: url, title: "Video_\(Int(Date().timeIntervalSince1970))", completion: completion)
            return
        }
        
        // 4. Đa nền tảng khác: YouTube, Instagram, X/Twitter...
        downloadUniversal(url: url, completion: completion)
    }
    
    // MARK: - Facebook Engine
    private func downloadFacebook(url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.main.async {
            self.statusMessage = "Đang bóc tách Facebook Reels..."
            self.progress = 0.25
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.7 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, let html = String(data: data, encoding: .utf8) else {
                self.downloadUniversal(url: url, completion: completion)
                return
            }
            
            let patterns = [
                "browser_native_hd_url[\"']?\\s*:\\s*[\"'](https:[^\"']+)[\"']",
                "browser_native_sd_url[\"']?\\s*:\\s*[\"'](https:[^\"']+)[\"']",
                "playable_url_quality_hd[\"']?\\s*:\\s*[\"'](https:[^\"']+)[\"']",
                "playable_url[\"']?\\s*:\\s*[\"'](https:[^\"']+)[\"']",
                "\"(https:\\\\/\\\\/[^\"']+fbcdn\\.net[^\"']+\\.mp4[^\"']*)\"",
                "property=[\"']og:video[\"']\\s+content=[\"'](https:[^\"']+)[\"']",
                "property=[\"']og:video:secure_url[\"']\\s+content=[\"'](https:[^\"']+)[\"']"
            ]
            
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
                   let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
                   let range = Range(match.range(at: 1), in: html) {
                    
                    var videoURLStr = String(html[range])
                    videoURLStr = videoURLStr.replacingOccurrences(of: "\\/", with: "/")
                    videoURLStr = videoURLStr.replacingOccurrences(of: "\\u0025", with: "%")
                    videoURLStr = videoURLStr.replacingOccurrences(of: "&amp;", with: "&")
                    
                    if let directURL = URL(string: videoURLStr) {
                        self.downloadDirectFile(url: directURL, title: "FB_Reels_\(Int(Date().timeIntervalSince1970))", completion: completion)
                        return
                    }
                }
            }
            
            // Nếu không tìm thấy trong HTML, chuyển sang Universal API
            self.downloadUniversal(url: url, completion: completion)
        }.resume()
    }
    
    // MARK: - TikTok Engine
    private func downloadTikTok(url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let apiURL = URL(string: "https://www.tikwm.com/api/?url=\(url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            downloadUniversal(url: url, completion: completion)
            return
        }
        
        URLSession.shared.dataTask(with: apiURL) { data, response, error in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataDict = json["data"] as? [String: Any],
               let playUrlStr = dataDict["play"] as? String,
               let directURL = URL(string: playUrlStr) {
                
                let title = dataDict["title"] as? String ?? "TikTok_Video"
                self.downloadDirectFile(url: directURL, title: title, completion: completion)
            } else {
                self.downloadUniversal(url: url, completion: completion)
            }
        }.resume()
    }
    
    // MARK: - Universal Engine (Cobalt)
    private func downloadUniversal(url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.main.async {
            self.statusMessage = "Đang bóc tách chất lượng cao..."
            self.progress = 0.3
        }
        
        guard let apiURL = URL(string: "https://api.cobalt.tools/") else {
            completion(.failure(NSError(domain: "QuickSave", code: 500, userInfo: [NSLocalizedDescriptionKey: "Lỗi cấu hình mạng."])))
            return
        }
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let body: [String: Any] = [
            "url": url.absoluteString,
            "videoQuality": "1080",
            "audioFormat": "mp3"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                if let directURLStr = json["url"] as? String, let downloadURL = URL(string: directURLStr) {
                    let title = json["filename"] as? String ?? "Video_\(Int(Date().timeIntervalSince1970))"
                    self.downloadDirectFile(url: downloadURL, title: title, completion: completion)
                    return
                }
            }
            
            // Nếu không lấy được URL tải hợp lệ, báo lỗi rõ ràng chứ KHÔNG tải nhầm trang HTML
            let err = NSError(domain: "QuickSave", code: 404, userInfo: [NSLocalizedDescriptionKey: "Không thể giải mã luồng video này. Vui lòng thử lại!"])
            DispatchQueue.main.async {
                self.isDownloading = false
                self.statusMessage = err.localizedDescription
            }
            completion(.failure(err))
        }.resume()
    }
    
    // MARK: - Download & Save to Camera Roll
    private func downloadDirectFile(url: URL, title: String, completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.main.async {
            self.statusMessage = "Đang tải video về máy..."
            self.progress = 0.6
        }
        
        let task = URLSession.shared.downloadTask(with: url) { tempLocalURL, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.statusMessage = "Lỗi tải: \(error.localizedDescription)"
                }
                completion(.failure(error))
                return
            }
            
            guard let tempLocalURL = tempLocalURL else {
                let err = NSError(domain: "QuickSave", code: 404, userInfo: [NSLocalizedDescriptionKey: "Không nhận được tệp video."])
                DispatchQueue.main.async { self.isDownloading = false }
                completion(.failure(err))
                return
            }
            
            // Kiểm tra dung lượng file tải về: Phải > 50KB mới là video thật
            guard let fileAttrs = try? FileManager.default.attributesOfItem(atPath: tempLocalURL.path),
                  let fSize = fileAttrs[.size] as? Int64, fSize > 50000 else {
                let err = NSError(domain: "QuickSave", code: 400, userInfo: [NSLocalizedDescriptionKey: "Link không chứa file video hợp lệ (hoặc trang yêu cầu đăng nhập)."])
                DispatchQueue.main.async {
                    self.isDownloading = false
                    self.statusMessage = err.localizedDescription
                }
                completion(.failure(err))
                return
            }
            
            // Lưu vào thư mục Documents của App
            let fileManager = FileManager.default
            let docsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let cleanTitle = title.replacingOccurrences(of: "[^a-zA-Z0-9_\\s-]", with: "", options: .regularExpression).prefix(30)
            let destinationURL = docsDir.appendingPathComponent("\(cleanTitle)_\(Int(Date().timeIntervalSince1970)).mp4")
            
            do {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.moveItem(at: tempLocalURL, to: destinationURL)
                
                // Lưu vào Cuộn Camera (Album Ảnh)
                self.saveToPhotosAlbum(fileURL: destinationURL) { success, photoError in
                    DispatchQueue.main.async {
                        self.isDownloading = false
                        if success {
                            self.progress = 1.0
                            self.statusMessage = "Đã lưu vào Album Ảnh thành công!"
                            self.addToHistory(title: String(cleanTitle), sourceURL: url.absoluteString, localURL: destinationURL)
                            completion(.success(destinationURL))
                        } else {
                            // BÁO LỖI THẬT THÀ NẾU KHÔNG LƯU ĐƯỢC VÀO ẢNH
                            let err = photoError ?? NSError(domain: "QuickSave", code: 500, userInfo: [NSLocalizedDescriptionKey: "Không thể lưu vào Album Ảnh! Kiểm tra dung lượng iPhone xem có bị đầy không."])
                            self.statusMessage = "Lỗi lưu: \(err.localizedDescription)"
                            completion(.failure(err))
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async { self.isDownloading = false }
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    // MARK: - Save to Photos Library
    func saveToPhotosAlbum(fileURL: URL, completion: @escaping (Bool, Error?) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized || status == .limited {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
                }) { success, error in
                    completion(success, error)
                }
            } else {
                completion(false, NSError(domain: "QuickSave", code: 403, userInfo: [NSLocalizedDescriptionKey: "Chưa cấp quyền truy cập Album Ảnh cho Quick Save!"]))
            }
        }
    }
    
    // MARK: - Helpers
    private func extractURL(from text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        if let match = matches?.first, let range = Range(match.range, in: text) {
            return URL(string: String(text[range]))
        }
        return URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    private func addToHistory(title: String, sourceURL: String, localURL: URL) {
        let attributes = try? FileManager.default.attributesOfItem(atPath: localURL.path)
        let size = attributes?[.size] as? Int64 ?? 0
        let item = DownloadItem(title: title.isEmpty ? "Video đã tải" : title, sourceURL: sourceURL, localFilePath: localURL.path, date: Date(), fileSize: size)
        self.history.insert(item, at: 0)
        saveHistory()
    }
    
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: "QuickSave_History")
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "QuickSave_History"),
           let decoded = try? JSONDecoder().decode([DownloadItem].self, from: data) {
            self.history = decoded
        }
    }
}
