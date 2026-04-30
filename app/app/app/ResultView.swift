import SwiftUI

struct ResultView: View {
    let image: UIImage
    let result: ImageResponse
    let onDismiss: () -> Void

    @State private var showShare = false
    @State private var shareImage: UIImage?
    @State private var savedToPhotos = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                Text("딥페이크 노이즈")
                    .font(.headline)
                    .padding(.top, 10)
                
                HStack(spacing: 12) {
                    VStack {
                        Text("원본")
                            .font(.caption).bold()
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 160, height: 160)
                            .clipped()
                            .cornerRadius(10)
                    }

                    VStack {
                        Text("필터 적용")
                            .font(.caption).bold()
                        AsyncImage(url: URL(string: result.resultUrl)) { img in
                            img.resizable()
                                .scaledToFill()
                                .frame(width: 160, height: 160)
                                .clipped()
                                .cornerRadius(10)
                        } placeholder: {
                            Color.gray.opacity(0.2)
                                .frame(width: 160, height: 160)
                                .cornerRadius(10)
                                .overlay(ProgressView())
                        }
                    }
                }
                .padding(.horizontal)

                AsyncImage(url: URL(string: result.resultUrl)) { img in
                    img.resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                } placeholder: {
                    ProgressView()
                }
                .padding(.horizontal)

                Button {
                    onDismiss()
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

                HStack(spacing: 12) {
                    Button {
                        loadImageFromURL(result.resultUrl)
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
                            Image(systemName: savedToPhotos ? "checkmark" : "arrow.down")
                            Text(savedToPhotos ? "저장됨" : "저장")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(savedToPhotos ? Color.green : Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
        }
        .sheet(isPresented: $showShare) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
        }
    }

    func loadImageFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let img = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.shareImage = img
                    self.showShare = true
                }
            }
        }.resume()
    }

    func loadAndSaveImage() {
        guard let url = URL(string: result.resultUrl) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let img = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                withAnimation { self.savedToPhotos = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.savedToPhotos = false }
            }
            DispatchQueue.global(qos: .background).async {
                HistoryStore.shared.add(processed: img)
            }
        }.resume()
    }
}
