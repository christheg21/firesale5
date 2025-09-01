import FirebaseFirestore

struct Reservation: Identifiable, Codable {
    @DocumentID var id: String?
    let itemId: String
    let userId: String
    let storeId: String
    let status: String // pending, accepted, declined
    let createdAt: Timestamp
    let expiresAt: Timestamp
    let quantity: Int
    let pickupCode: String

    enum CodingKeys: String, CodingKey {
        case id
        case itemId
        case userId
        case storeId
        case status
        case createdAt
        case expiresAt
        case quantity
        case pickupCode
    }
}
