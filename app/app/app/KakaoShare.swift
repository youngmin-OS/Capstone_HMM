import UIKit
import KakaoSDKShare
import KakaoSDKTemplate
import KakaoSDKCommon

struct KakaoShare {
    
    static func share(imageURL: String?, localImage: UIImage? = nil) {
        if let urlString = imageURL, !urlString.isEmpty {
            shareWithURL(urlString)
        } else {
            // URL 없으면 카카오톡 앱만 열기
            openKakaoTalk()
        }
    }
    
    private static func shareWithURL(_ imageURL: String) {
        guard let imageUrl = URL(string: imageURL) else { return }
        
        let content = FeedTemplate(
            content: Content(
                title: "딥페이크 방지 이미지",
                imageUrl: imageUrl,
                description: "FaceShield로 보호된 이미지입니다",
                link: Link()
            )
        )
        
        if ShareApi.isKakaoTalkSharingAvailable() {
            ShareApi.shared.shareDefault(templatable: content) { sharingResult, error in
                if let error = error {
                    print("카카오톡 공유 실패: \(error)")
                    return
                }
                if let result = sharingResult {
                    UIApplication.shared.open(result.url)
                }
            }
        } else {
            if let url = URL(string: "https://apps.apple.com/app/kakaotalk/id362057947") {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private static func openKakaoTalk() {
        if let url = URL(string: "kakaolink://send") {
            UIApplication.shared.open(url)
        }
    }
    
    static var isInstalled: Bool {
        ShareApi.isKakaoTalkSharingAvailable()
    }
}
