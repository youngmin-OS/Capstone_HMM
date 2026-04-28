import SwiftUI

// MARK: - 이력 항목 모델
struct HistoryItem: Identifiable, Codable {
    let id: UUID
    let date: Date
    let originalImageData: Data
    let processedImageData: Data

    init(id: UUID = UUID(), date: Date = Date(), originalImageData: Data, processedImageData: Data) {
        self.id = id
        self.date = date
        self.originalImageData = originalImageData
        self.processedImageData = processedImageData
    }
}

// MARK: - 이력 저장소 (싱글톤)
class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published var items: [HistoryItem] = []

    private let saveKey = "deepfake_history"

    private init() { load() }

    func add(original: UIImage, processed: UIImage) {
        guard let origData = original.jpegData(compressionQuality: 0.8),
              let procData = processed.jpegData(compressionQuality: 0.8) else { return }
        let item = HistoryItem(originalImageData: origData, processedImageData: procData)
        items.insert(item, at: 0)
        save()
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            items = decoded
        }
    }
}

// MARK: - 이력관리 메인 뷰
struct HistoryView: View {
    @EnvironmentObject private var store: HistoryStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItem: HistoryItem? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView

                if store.items.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                            ForEach(store.items) { item in
                                HistoryCard(item: item)
                                    .onTapGesture { selectedItem = item }
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .sheet(item: $selectedItem) { item in
                HistoryDetailView(item: item)
                    .environmentObject(store)
            }
        }
    }

    private var headerView: some View {
        ZStack {
            LinearGradient(colors: [Color.purple, Color.blue],
                           startPoint: .leading, endPoint: .trailing)
                .ignoresSafeArea(edges: .top)

            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("이력관리")
                        .font(.title2).bold()
                        .foregroundColor(.white)
                    Text("총 \(store.items.count)개의 처리 이미지")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.clear)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(height: 90)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "photo.stack")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundColor(.purple.opacity(0.4))
            Text("아직 처리된 이미지가 없습니다")
                .font(.headline)
                .foregroundColor(.gray)
            Text("이미지에 딥페이크 노이즈를 적용하면\n이곳에서 이력을 확인할 수 있어요")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }
}

// MARK: - 이력 카드
struct HistoryCard: View {
    let item: HistoryItem

    private var processedImage: UIImage? { UIImage(data: item.processedImageData) }

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "MM.dd HH:mm"
        return f.string(from: item.date)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let img = processedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 140)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color(.systemGray5))
                    .frame(height: 140)
            }

            Text(dateString)
                .font(.caption2)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.5))
                .cornerRadius(6)
                .padding(8)
        }
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

// MARK: - 이력 상세 뷰
struct HistoryDetailView: View {
    let item: HistoryItem
    @Environment(\.dismiss) private var dismiss

    @State private var savedToPhotos = false

    private var processedImage: UIImage? { UIImage(data: item.processedImageData) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 이미지
                if let proc = processedImage {
                    Image(uiImage: proc)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(14)
                        .padding(.horizontal)
                }

                // 저장 / 공유
                HStack(spacing: 12) {
                    Button { saveToPhotos() } label: {
                        HStack {
                            Image(systemName: savedToPhotos ? "checkmark" : "arrow.down.circle")
                            Text(savedToPhotos ? "저장됨" : "사진 저장")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(savedToPhotos ? Color.green : Color.blue)
                        .cornerRadius(10)
                    }

                    if let proc = processedImage {
                        ShareLink(item: Image(uiImage: proc), preview: SharePreview("처리된 이미지")) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("공유")
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.purple)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 16)
            .navigationTitle("상세 보기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private func saveToPhotos() {
        guard let img = processedImage else { return }
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
        withAnimation { savedToPhotos = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedToPhotos = false }
    }
}

// MARK: - Preview
#Preview {
    HistoryView()
        .environmentObject(HistoryStore.shared)
}
