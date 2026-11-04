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
        
        // 1. TikTok: Bóc tách trực tiếp không logo qua TikWM
        if absoluteString.contains("tiktok.com") {
            downloadTikTok(url: url, completion: completion)
            return
        }
        
        // 2. Link file MP4 trực tiếp
        if absoluteString.hasSuffix(".mp4") || absoluteString.contains(".mp4?") {
            downloadDirectFile(url: url, title: "Video_\(Int(Date().timeIntervalSince1970))", completion: completion)
            return
        }
        
        // 3. Đa nền tảng: YouTube, Facebook, Instagram, Twitter, Threads...
        downloadUniversal(url: url, completion: completion)
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
                // Fallback nếu API tiktok bận
                self.downloadUniversal(url: url, completion: completion)
            }
        }.resume()
    }
    
    // MARK: - Universal Engine (Cobalt / yt-dlp)
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
                
                // Trường hợp 1: Trả về link download trực tiếp
                if let directURLStr = json["url"] as? String, let downloadURL = URL(string: directURLStr) {
                    let title = json["filename"] as? String ?? "Video_\(Int(Date().timeIntervalSince1970))"
                    self.downloadDirectFile(url: downloadURL, title: title, completion: completion)
                    return
                }
            }
            
            // Trường hợp 2: Thử tải trực tiếp từ URL gốc
            self.downloadDirectFile(url: url, title: "Video_\(Int(Date().timeIntervalSince1970))", completion: completion)
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
                    self.statusMessage = "Lỗi: \(error.localizedDescription)"
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
                        self.progress = 1.0
                        if success {
                            self.statusMessage = "Đã lưu vào Album Ảnh thành công!"
                            self.addToHistory(title: String(cleanTitle), sourceURL: url.absoluteString, localURL: destinationURL)
                            completion(.success(destinationURL))
                        } else {
                            self.statusMessage = "Đã tải xong (Chưa cấp quyền Album ảnh)"
                            completion(.success(destinationURL))
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
                completion(false, NSError(domain: "QuickSave", code: 403, userInfo: [NSLocalizedDescriptionKey: "Chưa cấp quyền truy cập Ảnh."]))
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
