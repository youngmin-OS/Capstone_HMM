import SwiftUI

struct ResultView: View {
    @State private var showShare = false
    @State private var shareImage: UIImage?
    @State private var showSaveAlert = false
    
    func loadImageFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.shareImage = image
                    self.showShare = true
                }
            }
        }.resume()
    }
    
    func saveImageToPhotos(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
    
    func loadAndSaveImage() {
        guard let url = URL(string: result.processedUrl) else { return }
        
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    saveImageToPhotos(image)
                    print("저장 완료")
                    showSaveAlert = true
                }
            }
        }.resume()
    }
    
    let result: ImageResponse
    
    var riskText: String {
        result.riskScore > 0.5 ? "높음" : "낮음"
    }
    
    var riskColor: Color {
        result.riskScore > 0.5 ? .orange : .green
    }
    
    var body: some View {
        VStack(spacing: 16) {
            
            Text("딥페이크 노이즈")
                .font(.headline)
                .padding(.top, 10)
            
            VStack(alignment: .leading, spacing: 10) {
                
                HStack {
                    Circle()
                        .fill(riskColor.opacity(0.2))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "exclamationmark")
                                .foregroundColor(riskColor)
                        )
                    
                    VStack(alignment: .leading) {
                        Text("딥페이크 위험도: \(riskText) \(Int(result.riskScore * 100))%")
                            .font(.headline)
                            .foregroundColor(riskColor)
                        
                        Text("딥페이크 위험도가 \(riskText)습니다")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                
                ProgressView(value: result.riskScore)
                    .tint(riskColor)
                
                Text("⚠️ 이미지에서 의심스러운 조작 흔적이 발견되었습니다")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(16)
            .padding(.horizontal)
            
            AsyncImage(url: URL(string: result.processedUrl)) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
            } placeholder: {
                ProgressView()
            }
            .padding(.horizontal)
            
            Button {
                // 뒤로가기
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("새 이미지")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("원본과 비교")
                    .font(.headline)
                
                HStack(spacing: 10) {
                    
                    VStack {
                        Text("원본")
                            .font(.caption)
                        
                        AsyncImage(url: URL(string: result.originalUrl)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                        .frame(width: 120, height: 120)
                        .clipped()
                        .cornerRadius(10)
                    }
                    
                    VStack {
                        Text("효과 적용")
                            .font(.caption)
                        
                        AsyncImage(url: URL(string: result.processedUrl)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.gray.opacity(0.2)
                        }
                        .frame(width: 120, height: 120)
                        .clipped()
                        .cornerRadius(10)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
            .padding(.horizontal)
            
            Spacer()
            
            HStack(spacing: 12) {
                
                Button {
                    loadImageFromURL(result.processedUrl)
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("공유")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                
                Button {
                    loadAndSaveImage()
                } label: {
                    HStack {
                        Image(systemName: "arrow.down")
                        Text("저장")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            .sheet(isPresented: $showShare) {
                if let image = shareImage {
                    ShareSheet(items: [image])
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
        }
    }
}

#Preview {
    ResultView(result: ImageResponse(
        imageId: 1,
        originalUrl: "https://picsum.photos/200",
        processedUrl: "https://picsum.photos/200",
        riskScore: 0.72
    ))
}
