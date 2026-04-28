import SwiftUI

struct ResultLoadingView: View {
    let image: UIImage
    
    @State private var result: ImageResponse?
    @State private var goNext = false
    @State private var isLoading = true
    @State private var isError = false
    
    var body: some View {
        VStack(spacing: 20) {
            
            if isLoading {
                Text("AI 분석 중...")
                    .font(.title2)
                ProgressView()
            }
            
            if isError {
                Text("업로드 실패 😢")
                    .foregroundColor(.red)
                Button("다시 시도") {
                    upload()
                }
            }
            
            // ✅ result가 있을 때만 NavigationLink 활성화
            NavigationLink("", isActive: $goNext) {
                if let result = result {
                    ResultView(result: result)
                } else {
                    EmptyView()
                }
            }
        }
        .onAppear {
            upload()
        }
    }
    
    func upload() {
        isLoading = true
        isError = false
        
        uploadImage(image: image) { res in
            DispatchQueue.main.async {
                isLoading = false
                
                if let res = res {
                    print("✅ 성공: \(res)")
                    self.result = res
                    self.goNext = true  // ✅ result 설정 후 이동
                    
                } else {
                    print("❌ 실패: res가 nil")
                    self.isError = true
                }
            }
        }
    }
}
