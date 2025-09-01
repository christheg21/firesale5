import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct BuyerView: View {
    @ObservedObject var auth: AuthService
    @State private var cartItems: [Item] = []
    @State private var reservedItems: [Item: Date] = [:]
    @State private var favoriteItems: [Item] = []
    @State private var stores: [Store] = []
    @State private var isLoading = true
    private let db = Firestore.firestore()

    var body: some View {
        TabView {
            DealsView(cartItems: $cartItems, reservedItems: $reservedItems, favoriteItems: $favoriteItems)
                .tabItem {
                    Image(systemName: "cart")
                    Text("Deals")
                }
            
            SearchView(cartItems: $cartItems, reservedItems: $reservedItems, favoriteItems: $favoriteItems)
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
            
            MapView(stores: stores, cartItems: $cartItems, reservedItems: $reservedItems, favoriteItems: $favoriteItems)
                .tabItem {
                    Image(systemName: "map")
                    Text("Map")
                }
            
            ReservationsView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Reservations")
                }
            
            ProfileView(auth: auth, favoriteItems: $favoriteItems)
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
        }
        .tabViewStyle(DefaultTabViewStyle())
        .accentColor(.black)
        .toolbarBackground(.visible, for: .tabBar)
        .onAppear {
            fetchItemsAndStores()
            fetchCart()
            fetchFavorites()
            print("BuyerView rendered with \(cartItems.count) cart items at \(Date())")
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            cleanUpExpiredReservations()
        }
        .padding(.top, 20)  // Added padding to re-scale and fill space after removing title
    }

    private func fetchItemsAndStores() {
        db.collection("items").getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching items: \(error)")
                isLoading = false
                return
            }
            let items = snapshot?.documents.compactMap { try? $0.data(as: Item.self) } ?? []
            let storeDict = Dictionary(grouping: items, by: { $0.storeId })
            DispatchQueue.main.async {
                self.stores = storeDict.map { storeId, items in
                    let firstItem = items.first!
                    return Store(
                        id: storeId,
                        name: firstItem.storeName,
                        description: "Items from \(firstItem.storeName)",
                        location: "Unknown",
                        latitude: firstItem.location.latitude,
                        longitude: firstItem.location.longitude
                    )
                }
                self.isLoading = false
                print("Fetched \(items.count) items, derived \(self.stores.count) stores: \(self.stores.map { $0.name })")
            }
        }
    }

    private func fetchCart() {
        guard let userId = auth.user?.uid else { return }
        db.collection("carts").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching cart: \(error)")
                return
            }
            if let data = snapshot?.data(),
               let items = try? Firestore.Decoder().decode([Item].self, from: data["items"] ?? []),
               let reservations = data["reservations"] as? [String: Timestamp] {
                DispatchQueue.main.async {
                    self.cartItems = items
                    self.reservedItems = items.reduce(into: [Item: Date]()) { dict, item in
                        if let id = item.id, let timestamp = reservations[id] {
                            dict[item] = timestamp.dateValue()
                        }
                    }
                    print("Fetched \(self.cartItems.count) cart items")
                }
            }
        }
    }

    private func fetchFavorites() {
        guard let userId = auth.user?.uid else { return }
        db.collection("favorites").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching favorites: \(error)")
                return
            }
            if let data = snapshot?.data(),
               let items = try? Firestore.Decoder().decode([Item].self, from: data["items"] ?? []) {
                DispatchQueue.main.async {
                    self.favoriteItems = items
                    print("Fetched \(self.favoriteItems.count) favorite items")
                }
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
        guard let userId = auth.user?.uid else { return }
        let reservations: [String: Any] = reservedItems.reduce(into: [String: Timestamp]()) { dict, entry in
            if let id = entry.key.id {
                dict[id] = Timestamp(date: entry.value)
            }
        }
        db.collection("carts").document(userId).setData([
            "items": try? Firestore.Encoder().encode(cartItems),
            "reservations": reservations
        ], merge: true) { error in
            if let error = error {
                print("Error updating cart: \(error)")
            }
        }
    }
}

#if DEBUG
struct BuyerView_Previews: PreviewProvider {
    static var previews: some View {
        BuyerView(auth: AuthService.shared)
    }
}
#endif
