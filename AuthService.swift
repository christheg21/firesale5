import Foundation
import FirebaseAuth
import FirebaseFirestore

final class AuthService: ObservableObject {
    @Published var user: FirebaseAuth.User?
    @Published var role: String?
    @Published var isLoading = false
    @Published var storeName: String?
    private var handle: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()

    static let shared = AuthService()

    private init() {
        print("AuthService initialized at \(Date()) with objectID: \(Unmanaged.passUnretained(self).toOpaque())")
        listenAuthState()
    }

    func listenAuthState() {
        if handle != nil {
            print("Auth listener already active at \(Date())")
            return
        }
        print("listenAuthState started at \(Date())")
        isLoading = true
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            DispatchQueue.main.async {
                print("Auth state changed: user = \(user?.uid ?? "nil") at \(Date())")
                self.user = user
                if let uid = user?.uid {
                    self.fetchRoleAndStoreName(uid: uid)
                } else {
                    self.role = nil
                    self.storeName = nil
                    self.isLoading = false
                }
            }
        }
    }

    func fetchRoleAndStoreName(uid: String, retryCount: Int = 2) {
        print("Fetching role and store name for uid: \(uid) at \(Date()), retry: \(retryCount)")
        let ref = db.collection("users").document(uid)
        ref.getDocument { [weak self] snap, err in
            guard let self = self else { return }
            if let err = err {
                print("Firestore error fetching role: \(err.localizedDescription) at \(Date())")
                if retryCount > 0 && (err as NSError).code == -1005 {
                    print("Retrying fetchRole due to network error")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.fetchRoleAndStoreName(uid: uid, retryCount: retryCount - 1)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.role = "buyer"
                        self.storeName = nil
                        self.isLoading = false
                    }
                }
                return
            }
            if let snap = snap, snap.exists, let data = snap.data() {
                print("Fetched document for uid \(uid): \(data) at \(Date())")
                let role = data["role"] as? String ?? "buyer"
                let storeName = (data["storeName"] as? String) ?? (data["address"] as? String) ?? ""
                DispatchQueue.main.async {
                    self.role = role
                    self.storeName = storeName
                    self.isLoading = false
                    print("fetchRole completed for uid \(uid), role: \(role), storeName: \(storeName)")
                }
            } else {
                print("No user document for uid \(uid) at \(Date())")
                DispatchQueue.main.async {
                    self.role = "buyer"
                    self.storeName = nil
                    self.isLoading = false
                }
            }
        }
    }

    func signIn(email: String, password: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("Signing in with email: \(email), password length: \(password.count) at \(Date())")
        isLoading = true
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, err in
            guard let self = self else { return }
            if let err = err {
                print("Sign-in error: \(err.localizedDescription) at \(Date())")
                DispatchQueue.main.async {
                    self.isLoading = false
                    completion(.failure(err))
                }
                return
            }
            guard let user = result?.user else {
                print("No user returned at \(Date())")
                DispatchQueue.main.async {
                    self.isLoading = false
                    let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user returned"])
                    completion(.failure(error))
                }
                return
            }
            print("Sign-in successful: \(user.uid) at \(Date())")
            DispatchQueue.main.async {
                self.user = user
                self.fetchRoleAndStoreName(uid: user.uid)
                completion(.success(()))
            }
        }
    }

    func signUp(email: String, password: String, role: String, address: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("Signing up with email: \(email), role: \(role), address: \(address) at \(Date())")
        isLoading = true
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, err in
            guard let self = self else { return }
            if let err = err {
                print("Sign-up error: \(err.localizedDescription) at \(Date())")
                DispatchQueue.main.async {
                    self.isLoading = false
                    completion(.failure(err))
                }
                return
            }
            guard let uid = result?.user.uid else {
                print("No uid after sign-up at \(Date())")
                DispatchQueue.main.async {
                    self.isLoading = false
                    let error = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No user ID returned"])
                    completion(.failure(error))
                }
                return
            }
            let data: [String: Any] = [
                "email": email,
                "role": role,
                "address": role == "seller" ? address : "",
                "storeName": role == "seller" ? address : "",
                "creditBalance": 300.0,
                "creditLedger": [[
                    "type": "ISSUE",
                    "amount": 300.0,
                    "timestamp": Timestamp(),
                    "reason": "Initial signup bonus"
                ]]
            ]
            print("Saving user data for uid \(uid): \(data) at \(Date())")
            db.collection("users").document(uid).setData(data) { err in
                if let err = err {
                    print("Error saving user data: \(err.localizedDescription) at \(Date())")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        completion(.failure(err))
                    }
                } else {
                    print("User data saved for uid \(uid) at \(Date())")
                    DispatchQueue.main.async {
                        self.user = result?.user
                        self.role = role
                        self.storeName = role == "seller" ? address : nil
                        self.isLoading = false
                        completion(.success(()))
                    }
                }
            }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            DispatchQueue.main.async { [weak self] in
                self?.user = nil
                self?.role = nil
                self?.storeName = nil
                self?.isLoading = false
                print("Signed out successfully at \(Date())")
            }
            if let listener = handle {
                Auth.auth().removeStateDidChangeListener(listener)
                handle = nil
            }
        } catch {
            print("Sign-out error: \(error.localizedDescription) at \(Date())")
        }
    }

    func spendCredits(amount: Double, reason: String, userId: String, completion: @escaping (Bool) -> Void) {
        let userRef = db.collection("users").document(userId)
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let userDoc: DocumentSnapshot
            do {
                userDoc = try transaction.getDocument(userRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
            let currentBalance = userDoc.data()?["creditBalance"] as? Double ?? 0.0
            if currentBalance < amount {
                return nil // Not enough credits
            }
            let newBalance = currentBalance - amount
            let ledgerEntry: [String: Any] = [
                "type": "SPEND",
                "amount": amount,
                "timestamp": Timestamp(),
                "reason": reason
            ]
            var ledger = userDoc.data()?["creditLedger"] as? [[String: Any]] ?? []
            ledger.append(ledgerEntry)
            transaction.updateData([
                "creditBalance": newBalance,
                "creditLedger": ledger
            ], forDocument: userRef)
            return true
        }) { _, error in
            if let error = error {
                print("Error spending credits: \(error)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }

    func topUpCredits(userId: String, completion: @escaping (Bool) -> Void) {
        let userRef = db.collection("users").document(userId)
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let userDoc: DocumentSnapshot
            do {
                userDoc = try transaction.getDocument(userRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
            let currentBalance = userDoc.data()?["creditBalance"] as? Double ?? 0.0
            let newBalance = currentBalance + 800.0 // Updated to 800 for your request
            let ledgerEntry: [String: Any] = [
                "type": "ISSUE",
                "amount": 800.0,
                "timestamp": Timestamp(),
                "reason": "Manual top-up"
            ]
            var ledger = userDoc.data()?["creditLedger"] as? [[String: Any]] ?? []
            ledger.append(ledgerEntry)
            transaction.updateData([
                "creditBalance": newBalance,
                "creditLedger": ledger
            ], forDocument: userRef)
            return true
        }) { _, error in
            if let error = error {
                print("Error topping up credits: \(error)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }

    deinit {
        if let listener = handle {
            Auth.auth().removeStateDidChangeListener(listener)
            print("Auth listener removed during deinit at \(Date())")
        }
    }
}

struct UserRole: Codable {
    let email: String
    let role: String
    let address: String
}
