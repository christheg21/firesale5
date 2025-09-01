import SwiftUI

struct TopFiresalesSection: View {
    let items: [Item]
    @Binding var cartItems: [Item]
    @Binding var reservedItems: [Item: Date]
    @Binding var favoriteItems: [Item]
    let isGridView: Bool

    var body: some View {
        VStack(alignment: .leading) {
            Text("Top Firesales")
                .font(.headline)
                .padding(.bottom, 4)
            
            if isGridView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(items, id: \.self) { item in  // Added id: \.self to fix duplicate nil ID warning
                        ItemBoxView(
                            item: item,
                            cartItems: $cartItems,
                            reservedItems: $reservedItems,
                            favoriteItems: $favoriteItems,
                            bottomText: "Discount: \(item.discountPercentage)%",
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
                        bottomText: "Discount: \(item.discountPercentage)%",
                        isNavLink: true
                    )
                }
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            print("TopFiresalesSection rendered at \(Date())")
        }
    }
}
