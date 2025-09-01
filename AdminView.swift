import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct AdminView: View {
    @State private var users: [UserData] = []
    @State private var lowBalanceThreshold = "50"
    @State private var issueAmount = ""
    @State private var refundAmount = ""
    @State private var showBanner: String? = nil
    private let db = Firestore.firestore()

    struct UserData: Identifiable {
        let id: String
        let email: String
        let role: String
        let creditBalance: Double
    }

    var body: some View {
        NavigationView {
            VStack {
                TextField("Low Balance Threshold (FireCredits)", text: $lowBalanceThreshold)
                    .keyboardType(.decimalPad)
                    .padding()
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                List {
                    ForEach(users.filter { lowBalanceThreshold.isEmpty || ($0.creditBalance <= (Double(lowBalanceThreshold) ?? 50)) }) { user in
                        VStack(alignment: .leading) {
                            Text("Email: \(user.email)")
                            Text("Role: \(user.role)")
                            Text("FireCredits: \(String(format: "%.0f", user.creditBalance))")
                            HStack {
                                TextField("Issue Credits", text: $issueAmount)
                                    .keyboardType(.decimalPad)
                                    .frame(width: 100)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                Button("Issue") {
                                    issueCredits(userId: user.id, amount: Double(issueAmount) ?? 0)
                                    issueAmount = ""
                                }
                                .disabled(issueAmount.isEmpty || Double(issueAmount) == nil)
                                TextField("Refund Credits", text: $refundAmount)
                                    .keyboardType(.decimalPad)
                                    .frame(width: 100)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                Button("Refund") {
                                    issueCredits(userId: user.id, amount: Double(refundAmount) ?? 0, reason: "Manual refund")
                                    refundAmount = ""
                                }
                                .disabled(refundAmount.isEmpty || Double(refundAmount) == nil)
                            }
                        }
                    }
                }

                if let bannerText = showBanner {
                    Text(bannerText)
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.green)
                        .cornerRadius(8)
                }
            }
            .onAppear {
                fetchUsers()
            }
            .navigationTitle("Admin")
        }
    }

    private func fetchUsers() {
        db.collection("users").getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching users: \(error)")
                return
            }
            let users = snapshot?.documents.compactMap { doc -> UserData? in
                let data = doc.data()
                guard let email = data["email"] as? String,
                      let role = data["role"] as? String,
                      let creditBalance = data["creditBalance"] as? Double else { return nil }
                return UserData(id: doc.documentID, email: email, role: role, creditBalance: creditBalance)
            } ?? []
            DispatchQueue.main.async {
                self.users = users
            }
        }
    }

    private func issueCredits(userId: String, amount: Double, reason: String = "Manual issue") {
        guard amount > 0 else {
            showBanner = "Invalid amount"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showBanner = nil }
            return
        }
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
            let newBalance = currentBalance + amount
            let ledgerEntry: [String: Any] = [
                "type": "ISSUE",
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
            DispatchQueue.main.async {
                if let error = error {
                    print("Error issuing credits: \(error)")
                    self.showBanner = "Failed to issue credits"
                } else {
                    self.showBanner = "Issued \(String(format: "%.0f", amount)) FireCredits"
                    self.fetchUsers()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.showBanner = nil
                }
            }
        }
    }
}
