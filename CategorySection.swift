import SwiftUI

struct CategorySection: View {
    let name: String
    let items: [Item]
    @Binding var isExpanded: Bool
    @Binding var cartItems: [Item]
    @Binding var reservedItems: [Item: Date]
    @Binding var favoriteItems: [Item]
    let isGridView: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if items.isEmpty {
                Text("No items in \(name)")
                    .foregroundColor(.gray)
                    .padding(.vertical, 8)
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
        } label: {
            Text(name)
                .font(.headline)
                .foregroundColor(.black)
        }
        .padding(.vertical, 8)
        .onAppear {
            print("CategorySection \(name) rendered at \(Date())")
        }
    }
}
