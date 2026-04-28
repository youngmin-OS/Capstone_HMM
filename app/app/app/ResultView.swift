import SwiftUI

struct ResultView: View {
    let result: ImageResponse

    @State private var showShare = false
    @State private var shareImage: UIImage?
    @State private var showSaveAlert = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {

            Text("딥페이크 노이즈")
                .font(.headline)
                .padding(.top, 10)

            AsyncImage(url: URL(string: result.resultUrl)) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
            } placeholder: {
                ProgressView()
            }
            .padding(.horizontal)

            Button {
                dismiss()
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

            Spacer()

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

    func loadAndSaveImage() {
        guard let url = URL(string: result.resultUrl) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                    showSaveAlert = true
                }
            }
        }.resume()
    }
}

#Preview {
    ResultView(result: ImageResponse(
        imageId: 1,
        resultUrl: "https://picsum.photos/200"
    ))
}
