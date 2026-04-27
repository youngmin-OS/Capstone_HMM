import SwiftUI

struct SignupView: View {
    @Binding var showSignup: Bool
    @Binding var showLogin: Bool
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    
    @State private var message = ""
    @State private var showAlert = false
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 20) {
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("회원가입")
                            .font(.title)
                            .bold()
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button {
                            showSignup = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white)
                        }
                    }
                    
                    Text("새 계정을 만드세요")
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding()
                .background(
                    LinearGradient(colors: [Color.blue, Color.purple],
                                   startPoint: .leading,
                                   endPoint: .trailing)
                )
                
                VStack(spacing: 15) {
                    CustomTextField(icon: "person", placeholder: "이름", text: $name)
                    CustomTextField(icon: "envelope", placeholder: "이메일", text: $email)
                    CustomSecureField(icon: "lock", placeholder: "비밀번호", text: $password)
                }
                .padding(.horizontal)
                
                Button("회원가입") {
                    signup()
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(colors: [Color.blue, Color.purple],
                                   startPoint: .leading,
                                   endPoint: .trailing)
                )
                .cornerRadius(12)
                .padding(.horizontal)
                
                HStack {
                    Text("이미 계정이 있으신가요?")
                        .foregroundColor(.gray)
                    
                    Button("로그인") {
                        showSignup = false
                        showLogin = true
                    }
                    .foregroundColor(.blue)
                }
                .font(.footnote)
                
                Spacer()
            }
            .frame(height: 500)
            .background(Color.white)
            .cornerRadius(25)
            .alert(isPresented: $showAlert) {
                Alert(title: Text(message))
            }
        }
    }
    
    func signup() {
        guard let url = URL(string: "http://127.0.0.1:8080/api/users/signup") else {
            print("URL 오류")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let body: [String: String] = [
            "name": name,
            "email": email,
            "password": password
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("JSON 변환 실패")
            return
        }
        
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            
            DispatchQueue.main.async {
                
                if let error = error {
                    message = "회원가입 실패: \(error.localizedDescription)"
                    showAlert = true
                    return
                }
                
                if let response = response as? HTTPURLResponse {
                    if response.statusCode == 200 || response.statusCode == 201 {
                        message = "회원가입 성공!"
                    } else {
                        message = "회원가입 실패 (코드: \(response.statusCode))"
                    }
                    showAlert = true
                }
            }
            
        }.resume()
    }
}

struct SignupView_Previews: PreviewProvider {
    static var previews: some View {
        SignupView(
            showSignup: .constant(true),
            showLogin: .constant(false)
        )
    }
}
