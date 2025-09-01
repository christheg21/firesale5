import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import CoreLocation

struct SellerStoreHomeView: View {
    @ObservedObject var auth: AuthService
    @State private var storeName = ""
    @State private var storeDescription = ""
    @State private var isEditing = false
    @State private var activeDeals: [Item] = []
    @State private var closedDeals: [Item] = []
    @State private var sortOption: SortOption = .default
    @State private var creditBalance: Double = 0.0  // Live FireCredit balance

    enum SortOption: String, CaseIterable, Identifiable {
        case `default` = "Default"
        case priceLowToHigh = "Price: Low to High"
        case priceHighToLow = "Price: High to Low"
        case timeLeft = "Time Left"
        var id: String { rawValue }
    }

    var sortedActiveDeals: [Item] {
        switch sortOption {
        case .default:
            return activeDeals
        case .priceLowToHigh:
            return activeDeals.sorted { $0.discountPrice < $1.discountPrice }
        case .priceHighToLow:
            return activeDeals.sorted { $0.discountPrice > $1.discountPrice }
        case .timeLeft:
            return activeDeals.sorted { $0.timeLeftInDays < $1.timeLeftInDays }
        }
    }

    var sortedClosedDeals: [Item] {
        switch sortOption {
        case .default:
            return closedDeals
        case .priceLowToHigh:
            return closedDeals.sorted { $0.discountPrice < $1.discountPrice }
        case .priceHighToLow:
            return closedDeals.sorted { $0.discountPrice > $1.discountPrice }
        case .timeLeft:
            return closedDeals.sorted { $0.timeLeftInDays < $1.timeLeftInDays }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFill()
                        .frame(height: 150)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2)))
                        .shadow(radius: 4)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 12) {
                        if isEditing {
                            TextField("Store Name", text: $storeName)
                                .font(.title2).bold()
                            TextEditor(text: $storeDescription)
                                .frame(height: 80)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        } else {
                            Text(storeName.isEmpty ? "Store Name" : storeName)
                                .font(.title2).bold()
                            Text(storeDescription.isEmpty ? "Add a description..." : storeDescription)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .lineLimit(3)
                        }

                        Button(action: toggleEditing) {
                            Text(isEditing ? "Save Details" : "Edit Details")
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(isEditing ? Color.green : Color.blue)
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 4)
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Live Deals")
                                .font(.headline)
                            Spacer()
                            Picker("", selection: $sortOption) {
                                ForEach(SortOption.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        .padding(.horizontal)

                        if sortedActiveDeals.isEmpty {
                            Text("No live deals")
                                .foregroundColor(.gray)
                                .padding()
                        } else {
                            ForEach(sortedActiveDeals) { item in
                                ItemBoxView(
                                    item: item,
                                    cartItems: .constant([]),
                                    reservedItems: .constant([:]),
                                    favoriteItems: .constant([]),
                                    bottomText: "Time Left: \(item.timeLeft)",
                                    isNavLink: false
                                )
                                .padding(.horizontal)
                            }
                        }

                        if !sortedClosedDeals.isEmpty {
                            Text("Closed Deals")
                                .font(.headline)
                                .padding([.top, .horizontal])
                            ForEach(sortedClosedDeals) { item in
                                ItemBoxView(
                                    item: item,
                                    cartItems: .constant([]),
                                    reservedItems: .constant([:]),
                                    favoriteItems: .constant([]),
                                    bottomText: "Status: Expired",
                                    isNavLink: false
                                )
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .padding(.top, 20)  // Added padding to re-scale and fill space after removing title
            .onAppear {
                loadProfile()
                loadDeals()
            }
        }
    }

    private func loadProfile() {
        guard let uid = auth.user?.uid else { return }
        Firestore.firestore().collection("users").document(uid)
            .getDocument { snap, error in
                if let error = error {
                    print("Firestore profile error: \(error.localizedDescription)")
                    return
                }
                if let data = snap?.data() {
                    DispatchQueue.main.async {
                        self.storeName = data["storeName"] as? String ?? ""
                        self.storeDescription = data["storeDescription"] as? String ?? ""
                    }
                }
            }
    }

    private func loadDeals() {
        guard let uid = auth.user?.uid else { return }
        Firestore.firestore().collection("items")
            .whereField("storeId", isEqualTo: uid)
            .getDocuments { snap, error in
                if let error = error {
                    print("Firestore deals error: \(error.localizedDescription)")
                    return
                }
                let all: [Item] = snap?.documents.compactMap { doc in
                    do {
                        return try doc.data(as: Item.self)
                    } catch {
                        print("Decoding error for doc \(doc.documentID): \(error)")
                        return nil
                    }
                } ?? []
                DispatchQueue.main.async {
                    self.activeDeals = all.filter { $0.timeLeftInDays > 0 }
                    self.closedDeals = all.filter { $0.timeLeftInDays <= 0 }
                }
            }
    }

    private func toggleEditing() {
        guard let uid = auth.user?.uid else {
            isEditing.toggle()
            return
        }
        if isEditing {
            let data: [String: Any] = [
                "storeName": storeName,
                "storeDescription": storeDescription
            ]
            Firestore.firestore().collection("users").document(uid)
                .setData(data, merge: true) { error in
                    if let error = error {
                        print("Error saving profile: \(error.localizedDescription)")
                    } else {
                        withAnimation { isEditing.toggle() }
                    }
                }
        } else {
            withAnimation { isEditing.toggle() }
        }
    }
}
