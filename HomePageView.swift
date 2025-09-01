import SwiftUI
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Combine

final class AuthViewModel: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var isLoading = true
    @Published var role: String?
    let authService: AuthService
    private var cancellables = Set<AnyCancellable>()

    init(authService: AuthService = AuthService.shared) {  // Use shared instance
        self.authService = authService
        self.user = authService.user
        self.role = authService.role
        self.isLoading = authService.isLoading
        listenAuth()
        if let currentUser = Auth.auth().currentUser {
            self.user = currentUser
            self.authService.fetchRoleAndStoreName(uid: currentUser.uid)
        }
        authService.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                self?.role = self?.authService.role
            }
            .store(in: &cancellables)
    }

    func listenAuth() {
        authService.listenAuthState()
    }

    func signIn(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        authService.signIn(email: email, password: password) { [weak self] result in
            if case .success = result {
                if let uid = self?.authService.user?.uid {
                    self?.authService.fetchRoleAndStoreName(uid: uid)
                }
            }
            completion(result)
        }
    }

    func signUp(email: String, password: String, role: String, address: String, completion: @escaping (Result<Void, Error>) -> Void) {
        authService.signUp(email: email, password: password, role: role, address: address, completion: completion)
    }

    func signOut() {
        authService.signOut()
    }
}

struct HomePageView: View {
    @StateObject private var auth = AuthViewModel()
    @State private var navigationTrigger = UUID()

    var body: some View {
        NavigationView {
            contentView
                .navigationTitle(auth.user == nil || auth.role == nil ? "Welcome to Firesale" : "FiresaleBeta")
                .background(Color(.systemBackground).edgesIgnoringSafeArea(.all))
                .toolbar {
                    if auth.user != nil {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: {
                                auth.signOut()
                            }) {
                                Text("Logout")
                            }
                        }
                    }
                }
        }
        .onAppear {
            print("HomePageView onAppear called at \(Date())")
            if auth.user == nil {
                print("Immediate check: user is nil, setting isLoading = false at \(Date())")
                auth.isLoading = false
                navigationTrigger = UUID()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    if auth.isLoading {
                        print("Loading timeout triggered at \(Date())")
                        auth.isLoading = false
                        navigationTrigger = UUID()
                    }
                }
            }
        }
        .onChange(of: auth.user) { _ in  // New syntax
            print("auth.user changed at \(Date())")
            navigationTrigger = UUID()
            if auth.user == nil {
                auth.isLoading = false
            }
        }
        .onChange(of: auth.role) { _ in  // New syntax
            print("auth.role changed at \(Date())")
            navigationTrigger = UUID()
        }
        .onChange(of: auth.isLoading) { newValue in  // New syntax
            print("auth.isLoading changed to: \(newValue) at \(Date())")
            if !newValue {
                navigationTrigger = UUID()
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if auth.isLoading {
            ProgressView("Loading…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.1))
        } else if auth.user == nil || auth.role == nil {
            SignInView(viewModel: auth)
                .id(navigationTrigger)
        } else {
            authenticatedView
        }
    }

    @ViewBuilder
    private var authenticatedView: some View {
        if auth.role == "seller" {
            SellerView(auth: auth.authService)
        } else if auth.role == "buyer" {
            BuyerView(auth: auth.authService)
        } else {
            Text("Unknown role: \(auth.role ?? "nil")")
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#if DEBUG
struct HomePageView_Previews: PreviewProvider {
    static var previews: some View {
        HomePageView()
    }
}
#endif
