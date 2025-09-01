import SwiftUI

struct FavoritesSection: View {
    let items: [Item]
    @Binding var cartItems: [Item]
    @Binding var reservedItems: [Item: Date]
    @Binding var favoriteItems: [Item]
    let isGridView: Bool

    var body: some View {
        VStack(alignment: .leading) {
            Text("Favorites")
                .font(.headline)
                .padding(.bottom, 4)
            
            if items.isEmpty {
                Text("No favorite items")
                    .foregroundColor(.gray)
            } else {
                if isGridView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(items, id: \.self) { item in  // Added id: \.self to fix duplicate nil ID warning
                            ItemBoxView(
                                item: item,
                                cartItems: $cartItems,
                                reservedItems: $reservedItems,
                                favoriteItems: $favoriteItems,
                                bottomText: "Time Left: \(item.timeLeft)",
                                isNavLink: true
                            )
                        }
                    }
                } else {
                    ForEach(items, id: \.self) { item in  // Added id: \.self to fix duplicate nil ID warning
                        ItemBoxView(
                            item: item,
                            cartItems: $cartItems,
                            reservedItems: $reservedItems,
                            favoriteItems: $favoriteItems,
                            bottomText: "Time Left: \(item.timeLeft)",
                            isNavLink: true
                        )
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            print("FavoritesSection rendered at \(Date())")
        }
    }
}
