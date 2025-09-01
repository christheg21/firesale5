import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import CoreLocation

struct ItemDetailView: View {
    let item: Item
    @Binding var cartItems: [Item]
    @Binding var reservedItems: [Item: Date]
    @Binding var favoriteItems: [Item]
    @State private var showBanner: String? = nil
    @State private var showConfirmation = false  // New: For confirmation pop-up
    private let db = Firestore.firestore()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AsyncImage(url: URL(string: item.photoUrl ?? "")) { phase in
                        if let image = phase.image {
                            image
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFill()
                        }
                    }
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(10)
                    .padding(.horizontal)

                    Text(item.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.horizontal)

                    Text("Store: \(item.storeName)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.horizontal)

                    HStack {
                        Text("£\(String(format: "%.2f", item.discountPrice))")
                            .font(.title2)
                            .foregroundColor(.green)
                        Spacer()
                        Text("Original: £\(String(format: "%.2f", item.originalPrice))")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .strikethrough()
                    }
                    .padding(.horizontal)

                    Text("Time Left: \(item.timeLeft)")
                        .font(.subheadline)
                        .foregroundColor(item.timeLeftColor)
                        .padding(.horizontal)

                    Text("Quantity Available: \(item.quantity)")
                        .font(.subheadline)
                        .padding(.horizontal)

                    Text("Category: \(item.category)")
                        .font(.subheadline)
                        .padding(.horizontal)

                    Button(action: {
                        print("Reserve button pressed for item \(item.name) at \(Date())")
                        addToCart()
                    }) {
                        Text(cartItems.contains(where: { $0.id == item.id }) ? "In Cart" : "Reserve Item (15 FireCredits)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(cartItems.contains(where: { $0.id == item.id }) ? Color.gray : Color.blue)
                            .cornerRadius(10)
                    }
                    .disabled(cartItems.contains(where: { $0.id == item.id }))
                    .padding(.horizontal)
                    .alert("Reservation Confirmed", isPresented: $showConfirmation) {  // New: Pop-up confirmation
                        Button("OK") {
                            // Navigate to reservations or stay
                        }
                    } message: {
                        Text("Your reservation request for \(item.name) has been sent. Check your Reservations tab for updates.")
                    }

                    Button(action: {
                        toggleFavorite()
                    }) {
                        Text(favoriteItems.contains(where: { $0.id == item.id }) ? "Remove from Favorites" : "Add to Favorites")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(favoriteItems.contains(where: { $0.id == item.id }) ? Color.red : Color.pink)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)

                    if let bannerText = showBanner {
                        Text(bannerText)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.green)
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                print("ItemDetailView rendered for \(item.name) at \(Date())")
            }
        }
    }

    private func addToCart() {
        guard let userId = Auth.auth().currentUser?.uid, !userId.isEmpty else {
            print("Sign in required to reserve, userId: nil")
            showBanner = "Please sign in to reserve items"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showBanner = nil }
            return
        }
        guard let itemId = item.id, !itemId.isEmpty else {
            print("Invalid item ID: \(item.id ?? "nil")")
            showBanner = "Invalid item, cannot reserve"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showBanner = nil }
            return
        }
        guard !cartItems.contains(where: { $0.id == itemId }) else {
            print("Item \(item.name) already in cart")
            showBanner = "\(item.name) is already in cart"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showBanner = nil }
            return
        }

        print("Starting reserve for item \(item.name), userId: \(userId)")
        spendCredits(amount: 15, reason: "Reserve \(item.name)", userId: userId) { success in
            print("Spend credits result: \(success)")
            if !success {
                DispatchQueue.main.async {
                    showBanner = "Not enough FireCredits (need 15)"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.showBanner = nil }
                }
                return
            }

            DispatchQueue.main.async {
                self.cartItems.append(item)
                self.reservedItems[item] = Date()
                self.showBanner = "\(item.name) reserved for 2 hours"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { self.showBanner = nil }
                }
                self.showConfirmation = true  // Trigger the pop-up
            }

            let reservationId = UUID().uuidString
            let expiresAt = Timestamp(date: Calendar.current.date(byAdding: .hour, value: 2, to: Date())!)
            db.collection("reservations").document(reservationId).setData([
                "itemId": itemId,
                "userId": userId,
                "storeId": item.storeId,
                "status": "pending",
                "createdAt": Timestamp(date: Date()),
                "expiresAt": expiresAt,
                "quantity": 1,
                "pickupCode": String(format: "%06d", Int.random(in: 0...999999))
            ]) { error in
                if let error = error {
                    print("Error saving reservation: \(error)")
                } else {
                    print("Reservation saved: \(reservationId)")
                }
            }

            db.collection("carts").document(userId).setData([
                "items": try? Firestore.Encoder().encode(self.cartItems),
                "reservations": [itemId: Timestamp(date: Date())] as [String: Any]
            ], merge: true) { error in
                if let error = error {
                    print("Error updating cart: \(error)")
                } else {
                    print("Cart updated for user \(userId)")
                }
            }
        }
    }

    private func toggleFavorite() {
        guard let userId = Auth.auth().currentUser?.uid, !userId.isEmpty else {
            showBanner = "Please sign in to favorite items"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showBanner = nil }
            return
        }
        guard let itemId = item.id else {
            showBanner = "Invalid item, cannot favorite"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showBanner = nil }
            return
        }
        DispatchQueue.main.async {
            if favoriteItems.contains(where: { $0.id == itemId }) {
                favoriteItems.removeAll { $0.id == itemId }
                showBanner = "\(item.name) removed from favorites"
            } else {
                favoriteItems.append(item)
                showBanner = "\(item.name) added to favorites"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { showBanner = nil }
            }
        }
        let favorites: [String: Any] = ["items": try? Firestore.Encoder().encode(favoriteItems)]
        db.collection("favorites").document(userId).setData(favorites, merge: true) { error in
            if let error = error {
                print("Error updating favorites: \(error)")
            }
        }
    }

    private func spendCredits(amount: Double, reason: String, userId: String, completion: @escaping (Bool) -> Void) {
        let userRef = db.collection("users").document(userId)
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let userDoc: DocumentSnapshot
            do {
                userDoc = try transaction.getDocument(userRef)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
            guard let data = userDoc.data(),
                  let creditBalance = data["creditBalance"] as? Double else {
                errorPointer?.pointee = NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No credit balance"])
                return nil
            }
            guard creditBalance >= amount else {
                return false
            }
            let newBalance = creditBalance - amount
            let ledgerEntry: [String: Any] = [
                "type": "SPEND",
                "amount": amount,
                "timestamp": Timestamp(),
                "reason": reason
            ]
            var ledger = data["creditLedger"] as? [[String: Any]] ?? []
            ledger.append(ledgerEntry)
            transaction.updateData([
                "creditBalance": newBalance,
                "creditLedger": ledger
            ], forDocument: userRef)
            return true
        }) { result, error in
            if let error = error {
                print("Error spending credits: \(error)")
                completion(false)
            } else if let success = result as? Bool {
                completion(success)
            } else {
                completion(false)
            }
        }
    }
}
