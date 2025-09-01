import SwiftUI
import FirebaseAuth

struct SignInView: View {
    @ObservedObject var viewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var role = "buyer"
    @State private var address = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 20) {
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)

            SecureField("Password", text: $password)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)

            Picker("Role", selection: $role) {
                Text("Buyer").tag("buyer")
                Text("Seller").tag("seller")
            }
            .pickerStyle(.segmented)

            if role == "seller" {
                TextField("Store Address", text: $address)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }

            Button("Sign In") {
                isProcessing = true
                viewModel.signIn(email: email, password: password) { result in
                    isProcessing = false
                    switch result {
                    case .success:
                        print("Sign-in successful at \(Date())")
                    case .failure(let error):
                        alertMessage = error.localizedDescription
                        showAlert = true
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || password.isEmpty || isProcessing)

            Button("Sign Up") {
                isProcessing = true
                viewModel.signUp(email: email, password: password, role: role, address: address) { result in
                    isProcessing = false
                    switch result {
                    case .success:
                        print("Sign-up successful at \(Date())")
                    case .failure(let error):
                        alertMessage = error.localizedDescription
                        showAlert = true
                    }
                }
            }
            .buttonStyle(.bordered)
            .disabled(email.isEmpty || password.isEmpty || isProcessing)

            if !alertMessage.isEmpty {  // Fixed: Use isEmpty instead of let binding for non-optional String
                Text(alertMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
        .navigationTitle("Welcome to Firesale")
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Status"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
}

#if DEBUG
struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView(viewModel: AuthViewModel())
    }
}
#endif
