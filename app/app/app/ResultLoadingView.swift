import SwiftUI

struct ResultLoadingView: View {
    let image: UIImage
    
    @State private var result: ImageResponse?
    @State private var goNext = false
    
    var body: some View {
        VStack(spacing: 20) {
            
            Text("분석 중...")
            
            ProgressView()
            
            if let result = result {
                Text("위험도: \(Int(result.riskScore * 100))%")
                
                NavigationLink("", isActive: $goNext) {
                    ResultView(result: result)
                }
            }
        }
        .onAppear {
            uploadImage(image: image) { res in
                self.result = res
                self.goNext = true
            }
        }
    }
}
