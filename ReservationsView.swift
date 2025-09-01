//
//  ReservationsView.swift
//  Firesale Pre-Alpha
//
//  Created by Christian Cournoyer on 7/24/25.
//


import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct ReservationsView: View {
    @State private var pendingReservations: [Reservation] = []
    @State private var confirmedReservations: [Reservation] = []
    private let db = Firestore.firestore()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Pending Reservations")
                        .font(.headline)
                    if pendingReservations.isEmpty {
                        Text("No pending reservations")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(pendingReservations) { reservation in
                            ReservationRow(reservation: reservation)
                        }
                    }

                    Text("Confirmed Reservations")
                        .font(.headline)
                    if confirmedReservations.isEmpty {
                        Text("No confirmed reservations")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(confirmedReservations) { reservation in
                            ReservationRow(reservation: reservation)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Reservations")
            .onAppear {
                fetchReservations()
            }
        }
    }

    private func fetchReservations() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        db.collection("reservations")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching reservations: \(error)")
                    return
                }
                let allReservations = snapshot?.documents.compactMap { try? $0.data(as: Reservation.self) } ?? []
                DispatchQueue.main.async {
                    self.pendingReservations = allReservations.filter { $0.status == "pending" }
                    self.confirmedReservations = allReservations.filter { $0.status == "accepted" }
                    print("Fetched \(allReservations.count) reservations")
                }
            }
    }
}

struct ReservationRow: View {
    let reservation: Reservation

    var body: some View {
        VStack(alignment: .leading) {
            Text("Item ID: \(reservation.itemId)")
                .font(.headline)
            Text("Status: \(reservation.status.capitalized)")
                .font(.subheadline)
            if reservation.status == "accepted" {
                Text("Pickup Code: \(reservation.pickupCode)")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            Text("Expires: \(reservation.expiresAt.dateValue(), formatter: dateFormatter)")
                .font(.caption)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

#if DEBUG
struct ReservationsView_Previews: PreviewProvider {
    static var previews: some View {
        ReservationsView()
    }
}
#endif