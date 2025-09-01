import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import CoreLocation  // For CLLocationCoordinate2D

struct SellerAddItemView: View {
    @ObservedObject var auth: AuthService
    @State private var name = ""
    @State private var originalPrice = ""
    @State private var discountPrice = ""
    @State private var timeLeft = ""
    @State private var quantity = ""
    @State private var category = ""
    @State private var photoUrl = ""
    @State private var showBanner: String? = nil
    private let db = Firestore.firestore()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Item Details")) {
                    TextField("Item Name", text: $name)
                    TextField("Original Price (£)", text: $originalPrice)
                        .keyboardType(.decimalPad)
                    TextField("Discount Price (£)", text: $discountPrice)
                        .keyboardType(.decimalPad)
                    TextField("Time Left (e.g., 3 days)", text: $timeLeft)
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.numberPad)
                    TextField("Category (e.g., Clothing)", text: $category)
                    TextField("Photo URL (optional)", text: $photoUrl)
                }
                Button(action: {
                    postItem()
                }) {
                    Text("Post Item (25 FireCredits)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .disabled(name.isEmpty || originalPrice.isEmpty || discountPrice.isEmpty || timeLeft.isEmpty || quantity.isEmpty || category.isEmpty)
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
            .navigationTitle("Add New Item")
        }
    }

    private func postItem() {
        guard let userId = Auth.auth().currentUser?.uid, !userId.isEmpty else {
            showBanner = "Please sign in to post items"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showBanner = nil }
            return
        }
        guard let originalPrice = Double(originalPrice),
              let discountPrice = Double(discountPrice),
              let quantity = Int(quantity) else {
            showBanner = "Invalid price or quantity"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showBanner = nil }
            return
        }
        guard let storeId = auth.storeName, !storeId.isEmpty else {
            showBanner = "Store information missing"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { showBanner = nil }
            return
        }

        // Deduct 25 FireCredits
        auth.spendCredits(amount: 25, reason: "Post item \(name)", userId: userId) { success in
            if !success {
                showBanner = "Not enough FireCredits (need 25)"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.showBanner = nil }
                return
            }

            let item = Item(
                name: name,
                originalPrice: originalPrice,
                discountPrice: discountPrice,
                storeName: storeId,
                timeLeft: timeLeft,
                location: CLLocationCoordinate2D(latitude: 51.4946499, longitude: 0.1619471),
                quantity: quantity,
                storeId: storeId,
                category: category,
                photoUrl: photoUrl.isEmpty ? nil : photoUrl,
                createdAt: Timestamp()
            )

            do {
                _ = try db.collection("items").addDocument(from: item) { error in
                    if let error = error {
                        print("Error posting item: \(error)")
                        showBanner = "Failed to post item"
                    } else {
                        showBanner = "\(name) posted successfully"
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { self.showBanner = nil }
                    }
                }
            } catch {
                print("Error encoding item: \(error)")
                showBanner = "Failed to post item"
            }
        }
    }
}

#if DEBUG
struct SellerAddItemView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SellerAddItemView(auth: AuthService.shared)
        }
    }
}
#endif
