import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct StorePopupView: View {
    let store: Store
    @Environment(\.dismiss) private var dismiss
    @Binding var cartItems: [Item]
    @Binding var reservedItems: [Item: Date]
    @Binding var favoriteItems: [Item]
    @State private var storeItems: [Item] = []
    @State private var showBanner: String? = nil
    private let db = Firestore.firestore()

    var body: some View {
        VStack(spacing: 16) {
            Text(store.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.black)
            
            Text("1.5 miles away") // Placeholder, adjust if generateRandomDistance exists
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Text("Available Deals")
                .font(.headline)
                .foregroundColor(.black)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(storeItems.prefix(3), id: \.self) { item in  // Already has id: \.self, but confirmed for stability
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.name)
                                    .font(.subheadline)
                                    .foregroundColor(.black)
                                Text("£\(String(format: "%.2f", item.discountPrice))")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text("Time Left: \(item.timeLeft)")
                                    .font(.caption)
                                    .foregroundColor(item.timeLeftColor)
                            }
                            Spacer()
                            VStack(spacing: 8) {
                                Button(action: { handleAddToCart(item: item) }) {
                                    Image(systemName: isInCart(item) ? "cart.fill" : "cart")
                                        .foregroundColor(.blue)
                                        .frame(width: 24, height: 24)
                                }
                                .disabled(isInCart(item))
                                .accessibilityLabel("Add \(item.name) to cart")

                                Button(action: { handleToggleFavorite(item: item) }) {
                                    Image(systemName: isFavorite(item) ? "heart.fill" : "heart")
                                        .foregroundColor(.red)
                                        .frame(width: 24, height: 24)
                                }
                                .accessibilityLabel(isFavorite(item) ? "Remove \(item.name) from favorites" : "Add \(item.name) to favorites")
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .frame(maxHeight: 120)
            
            Button("Close") {
                dismiss()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .accessibilityLabel("Close store popup")
            
            if let bannerText = showBanner {
                Text(bannerText)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.green)
                    .cornerRadius(8)
                    .transition(.opacity)
                    .accessibilityLabel(bannerText)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 4)
        .onAppear {
            fetchItems()
            cleanUpExpiredReservations()
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            cleanUpExpiredReservations()
        }
    }

    private func isInCart(_ item: Item) -> Bool {
        cartItems.contains(where: { $0.id == item.id })
    }

    private func isFavorite(_ item: Item) -> Bool {
        favoriteItems.contains(where: { $0.id == item.id })
    }

    private func handleAddToCart(item: Item) {
        guard let userId = Auth.auth().currentUser?.uid, !userId.isEmpty else {
            showBanner = "Please sign in to reserve items"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.showBanner = nil }
            return
        }
        guard let itemId = item.id, !itemId.isEmpty else {
            showBanner = "Invalid item, cannot reserve"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.showBanner = nil }
            return
        }
        guard !isInCart(item) else {
            showBanner = "\(item.name) is already in cart"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.showBanner = nil }
            return
        }

        spendCredits(amount: 15, reason: "Reserve \(item.name)", userId: userId) { success in
            if !success {
                DispatchQueue.main.async {
                    self.showBanner = "Not enough FireCredits (need 15)"
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
                }
            }

            db.collection("carts").document(userId).setData([
                "items": try? Firestore.Encoder().encode(self.cartItems),
                "reservations": [itemId: Timestamp(date: Date())] as [String: Any]
            ], merge: true) { error in
                if let error = error {
                    print("Error updating cart: \(error)")
                }
            }
        }
    }

    private func handleToggleFavorite(item: Item) {
        guard let userId = Auth.auth().currentUser?.uid, !userId.isEmpty else {
            showBanner = "Please sign in to favorite items"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.showBanner = nil }
            return
        }
        guard let itemId = item.id else {
            showBanner = "Invalid item, cannot favorite"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.showBanner = nil }
            return
        }
        DispatchQueue.main.async {
            if self.isFavorite(item) {
                self.favoriteItems.removeAll { $0.id == itemId }
                self.showBanner = "\(item.name) removed from favorites"
            } else {
                self.favoriteItems.append(item)
                self.showBanner = "\(item.name) added to favorites"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { self.showBanner = nil }
            }
        }
        db.collection("favorites").document(userId).setData([
            "items": try? Firestore.Encoder().encode(self.favoriteItems) as Any
        ], merge: true) { error in
            if let error = error {
                print("Error updating favorites: \(error)")
            }
        }
    }

    private func fetchItems() {
        db.collection("items")
            .whereField("storeId", isEqualTo: store.id ?? "")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching items for store \(self.store.id ?? ""): \(error)")
                    return
                }
                DispatchQueue.main.async {
                    self.storeItems = snapshot?.documents.compactMap { doc in
                        var item = try? doc.data(as: Item.self)
                        item?.id = doc.documentID // Ensure id is set
                        return item
                    } ?? []
                    print("Fetched \(self.storeItems.count) items for store \(self.store.name)")
                }
            }
    }

    private func cleanUpExpiredReservations() {
        let calendar = Calendar.current
        reservedItems = reservedItems.filter { item, reservationDate in
            guard let expirationDate = calendar.date(byAdding: .hour, value: 2, to: reservationDate) else {
                return false
            }
            return Date() < expirationDate
        }
        cartItems.removeAll { item in
            !reservedItems.keys.contains(where: { $0.id == item.id })
        }
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let reservations: [String: Any] = reservedItems.reduce(into: [String: Timestamp]()) { dict, entry in
            if let id = entry.key.id {
                dict[id] = Timestamp(date: entry.value)
            }
        }
        db.collection("carts").document(userId).setData([
            "items": try? Firestore.Encoder().encode(cartItems),
            "reservations": reservations
        ], merge: true)
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
