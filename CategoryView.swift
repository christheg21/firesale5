import SwiftUI
import CoreLocation
import FirebaseFirestore

struct CategoryView: View {
    let categoryName: String
    let items: [Item]
    @Binding var cartItems: [Item]
    @Binding var reservedItems: [Item: Date]
    @Binding var favoriteItems: [Item]

    var body: some View {
        List {
            ForEach(items) { item in
                NavigationLink(
                    destination: ItemDetailView(
                        item: item,
                        cartItems: $cartItems,
                        reservedItems: $reservedItems,
                        favoriteItems: $favoriteItems
                    )
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Store: \(item.storeName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Price: £\(String(format: "%.2f", item.discountPrice))")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle(categoryName)
        .onAppear {
            print("CategoryView rendered for \(categoryName) at \(Date())")
        }
    }
}

#if DEBUG
struct CategoryView_Previews: PreviewProvider {
    @State static var cart: [Item] = []
    @State static var reserved: [Item: Date] = [:]
    @State static var favorites: [Item] = []

    static var previews: some View {
        NavigationStack {
            CategoryView(
                categoryName: "Sample Category",
                items: [],  // Removed demo item to fix errors
                cartItems: $cart,
                reservedItems: $reserved,
                favoriteItems: $favorites
            )
        }
    }
}
#endif
