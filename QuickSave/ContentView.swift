import SwiftUI
import AVKit

struct ContentView: View {
    @StateObject private var engine = VideoDownloaderEngine.shared
    @AppStorage("pc_server_ip") private var pcServerIP = "192.168.1.14:4545"
    @State private var inputURL = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var showingSettings = false
    @State private var selectedVideoURL: URL?
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.07, green: 0.09, blue: 0.15)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Header Card
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.cyan)
                            Text("AT Downloader")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Button(action: { showingSettings = true }) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.gray)
                                    .padding(8)
                                    .background(Color(red: 0.12, green: 0.15, blue: 0.24))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal)
                        
                        Text("Tải video sạch mọi nền tảng • Đồng bộ AT Download Manager")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 10)
                    
                    // Input Card
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "link")
                                .foregroundColor(.cyan)
                            TextField("Dán link TikTok, YouTube, Facebook...", text: $inputURL)
                                .foregroundColor(.white)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            if !inputURL.isEmpty {
                                Button(action: { inputURL = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            } else {
                                Button(action: pasteFromClipboard) {
                                    Text("Dán")
                                        .font(.system(size: 12, weight: .semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Color.cyan.opacity(0.2))
                                        .foregroundColor(.cyan)
                                        .cornerRadius(6)
                                }
                            }
                        }
                        .padding(14)
                        .background(Color(red: 0.12, green: 0.15, blue: 0.24))
                        .cornerRadius(12)
                        
                        // Download Button
                        Button(action: startDownload) {
                            HStack {
                                if engine.isDownloading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .padding(.trailing, 6)
                                } else {
                                    Image(systemName: "arrow.down.to.line.compact")
                                }
                                Text(engine.isDownloading ? "Đang xử lý..." : "Tải Ngay")
                                    .bold()
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color.cyan, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(color: .cyan.opacity(0.3), radius: 8, y: 4)
                        }
                        .disabled(engine.isDownloading || inputURL.trimmingCharacters(in: .whitespaces).isEmpty)
                        
                        // Status & Progress
                        if engine.isDownloading || !engine.statusMessage.isEmpty {
                            VStack(spacing: 6) {
                                if engine.isDownloading {
                                    ProgressView(value: engine.progress, total: 1.0)
                                        .accentColor(.cyan)
                                }
                                Text(engine.statusMessage)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.cyan)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(16)
                    .background(Color(red: 0.10, green: 0.12, blue: 0.19))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // History Title
                    HStack {
                        Text("Video Đã Tải Về (\(engine.history.count))")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // History List
                    if engine.history.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "film.stack")
                                .font(.system(size: 48))
                                .foregroundColor(.gray.opacity(0.5))
                            Text("Chưa có video nào\nBấm chia sẻ từ app bất kỳ để tải nhanh!")
                                .multilineTextAlignment(.center)
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            Spacer()
                        }
                    } else {
                        List {
                            ForEach(engine.history) { item in
                                VideoRowView(item: item) {
                                    let url = URL(fileURLWithPath: item.localFilePath)
                                    if FileManager.default.fileExists(atPath: url.path) {
                                        selectedVideoURL = url
                                    } else {
                                        alertMessage = "File không tồn tại trên thiết bị."
                                        showingAlert = true
                                    }
                                }
                                .listRowBackground(Color(red: 0.10, green: 0.12, blue: 0.19))
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedVideoURL) { url in
                VideoPlayerSheet(url: url)
            }
            .sheet(isPresented: $showingSettings) {
                ZStack {
                    Color(red: 0.07, green: 0.09, blue: 0.15).ignoresSafeArea()
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Text("Cài Đặt Máy Chủ PC")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            Spacer()
                            Button("Xong") { showingSettings = false }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.cyan)
                        }
                        .padding(.top, 20)
                        
                        Text("Khi điện thoại cùng mạng Wi-Fi với máy tính, app sẽ tự động tải video chuẩn 1080p qua AT Download Manager trên PC mà không bị dính quảng cáo hay chặn bot.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Địa chỉ IP máy tính (Port 4545):")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.cyan)
                            TextField("192.168.1.14:4545", text: $pcServerIP)
                                .padding(12)
                                .background(Color(red: 0.12, green: 0.15, blue: 0.24))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Thông báo"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    private func pasteFromClipboard() {
        if let clip = UIPasteboard.general.string {
            inputURL = clip
        }
    }
    
    private func startDownload() {
        let url = inputURL.trimmingCharacters(in: .whitespacesAndNewlines)
        engine.processAndDownload(urlString: url) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    inputURL = ""
                    alertMessage = "Video đã được tải và lưu thành công vào Cuộn Camera!"
                    showingAlert = true
                case .failure(let err):
                    alertMessage = "Lỗi: \(err.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
}

// MARK: - Row View
struct VideoRowView: View {
    let item: VideoDownloaderEngine.DownloadItem
    let onPlay: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "video.fill")
                .font(.system(size: 22))
                .foregroundColor(.cyan)
                .frame(width: 44, height: 44)
                .background(Color.cyan.opacity(0.15))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(formatDate(item.date))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Text("•")
                        .foregroundColor(.gray)
                    Text(formatBytes(item.fileSize))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Button(action: onPlay) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.cyan)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm dd/MM"
        return formatter.string(from: date)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Video Player Sheet
extension URL: Identifiable {
    public var id: String { self.absoluteString }
}

struct VideoPlayerSheet: View {
    let url: URL
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VideoPlayer(player: AVPlayer(url: url))
        }
    }
}
