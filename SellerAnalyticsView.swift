import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import CoreLocation

struct SellerAnalyticsView: View {
    @StateObject private var auth = AuthService.shared
    @State private var selectedPeriod: TimePeriod = .last30Days
    @State private var salesMade = 0
    @State private var totalRevenue: Double = 0
    @State private var itemsSold = 0
    @State private var storeViews = 0
    @State private var salesData: [DailySales] = []
    @State private var categoryData: [CategoryStat] = []
    @State private var topItems: [TopItem] = []

    enum TimePeriod: String, CaseIterable, Identifiable {
        case last7Days = "Last 7 Days"
        case last30Days = "Last 30 Days"
        case allTime = "All Time"
        var id: String { rawValue }
        func dateRange() -> (from: Date, to: Date) {
            let now = Date()
            switch self {
            case .last7Days:
                return (Calendar.current.date(byAdding: .day, value: -7, to: now)!, now)
            case .last30Days:
                return (Calendar.current.date(byAdding: .day, value: -30, to: now)!, now)
            case .allTime:
                return (Date(timeIntervalSince1970: 0), now)
            }
        }
    }

    struct DailySales: Identifiable {
        let id = UUID()
        let day: String
        let sales: Double
    }

    struct CategoryStat: Identifiable {
        let id = UUID()
        let category: String
        let percentage: Double
    }

    struct TopItem: Identifiable {
        let id = UUID()
        let name: String
        let revenue: Double
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Time Period", selection: $selectedPeriod) {
                        ForEach(TimePeriod.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    VStack(spacing: 12) {
                        Text("Store Summary").font(.title2).bold()
                        HStack {
                            StatCard(title: "Sales Made", value: Double(salesMade))
                            StatCard(title: "Revenue", value: totalRevenue, isCurrency: true)
                            StatCard(title: "Items Sold", value: Double(itemsSold))
                            StatCard(title: "Views", value: Double(storeViews))
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 4)
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sales Over Time").font(.headline)
                        if salesData.isEmpty {
                            Text("No sales data").foregroundColor(.gray)
                        } else {
                            ForEach(salesData) { data in
                                HStack {
                                    Text(data.day).font(.subheadline)
                                    Spacer()
                                    Text(data.sales, format: .currency(code: "GBP"))
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 4)
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category Distribution").font(.headline)
                        if categoryData.isEmpty {
                            Text("No data").foregroundColor(.gray)
                        } else {
                            ForEach(categoryData) { cat in
                                HStack {
                                    Text(cat.category).font(.subheadline)
                                    Spacer()
                                    Text("\(cat.percentage, format: .percent)")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 4)
                    .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Top Items").font(.headline)
                        if topItems.isEmpty {
                            Text("No top items").foregroundColor(.gray)
                        } else {
                            ForEach(topItems) { ti in
                                HStack {
                                    Text(ti.name).font(.subheadline)
                                    Spacer()
                                    Text(ti.revenue, format: .currency(code: "GBP"))
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 4)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Analytics")
            .onAppear(perform: fetchAnalytics)
        }
    }

    private func fetchAnalytics() {
        guard let uid = auth.user?.uid else { return }
        let db = Firestore.firestore()
        let (from, to) = selectedPeriod.dateRange()

        db.collection("orders")
            .whereField("storeId", isEqualTo: uid)
            .whereField("timestamp", isGreaterThan: from)
            .whereField("timestamp", isLessThanOrEqualTo: to)
            .getDocuments { snap, _ in
                let orders = snap?.documents.compactMap { try? $0.data(as: Order.self) } ?? []
                DispatchQueue.main.async {
                    self.salesMade = orders.count
                    self.totalRevenue = orders.reduce(0) { $0 + $1.totalPrice }
                    self.itemsSold = orders.reduce(0) { $0 + $1.quantity }

                    let df = DateFormatter()
                    df.dateFormat = "MMM d"
                    var byDay = [String: Double]()
                    orders.forEach { o in
                        let day = df.string(from: o.timestamp ?? Date())
                        byDay[day, default: 0] += o.totalPrice
                    }
                    self.salesData = byDay.map { DailySales(day: $0.key, sales: $0.value) }
                                     .sorted { $0.day < $1.day }

                    var byItem = [String: Double]()
                    orders.forEach { o in byItem[o.itemName, default: 0] += o.totalPrice }
                    self.topItems = byItem.map { TopItem(name: $0.key, revenue: $0.value) }
                                     .sorted { $0.revenue > $1.revenue }

                    var byCat = [String: Int]()
                    orders.forEach { o in byCat[o.category, default: 0] += o.quantity }
                    self.categoryData = byCat.map { CategoryStat(category: $0.key, percentage: Double($0.value)/Double(self.itemsSold)) }
                }
            }

        db.collection("stores").document(uid)
            .collection("views")
            .getDocuments { snap, _ in
                DispatchQueue.main.async {
                    self.storeViews = snap?.documents.count ?? 0
                }
            }
    }

    struct Order: Codable {
        var storeId: String
        var itemName: String
        var category: String
        var quantity: Int
        var totalPrice: Double
        @ServerTimestamp var timestamp: Date?
    }

    struct StatCard: View {
        let title: String
        let value: Double
        var isCurrency = false

        var body: some View {
            VStack {
                Text(title).font(.caption).foregroundColor(.gray)
                if isCurrency {
                    Text(value, format: .currency(code: "GBP")).font(.headline)
                } else {
                    Text("\(Int(value))").font(.headline)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white)
            .cornerRadius(10)
            .shadow(radius: 2)
        }
    }
}
