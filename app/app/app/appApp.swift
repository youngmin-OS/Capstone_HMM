import SwiftUI
import KakaoSDKCommon
import KakaoSDKShare

@main
struct appApp: App {
    init() {
        KakaoSDK.initSDK(appKey: "0fcc49c1b5b1b6e41b7be7b0d95234c3")
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .onOpenURL { url in
                    // 카카오 딥링크 처리
                    if ShareApi.isKakaoTalkSharingUrl(url) {
                        
                    }
                }
        }
    }
}
