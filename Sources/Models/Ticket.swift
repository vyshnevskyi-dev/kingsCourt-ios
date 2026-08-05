import Foundation

struct Ticket: Identifiable, Hashable, Codable {
    let id: UUID
    let ticketNumber: String
    let section: String
    let row: String
    let seat: String
    let type: TicketType
    let holderName: String
    let eventName: String
    let eventDate: Date
    let qrCodeValue: String
    var isCheckedIn: Bool
    
    enum TicketType: String, Hashable, Codable {
        case standard = "Standard"
        case vip = "VIP"
        case backstage = "Backstage Access"
    }
    
    static let sampleTicket = Ticket(
        id: UUID(),
        ticketNumber: "KC-2024-1847",
        section: "VIP-01",
        row: "A",
        seat: "12",
        type: .vip,
        holderName: "Alex Johnson",
        eventName: "Kings Court Championship",
        eventDate: Date().addingTimeInterval(7200),
        qrCodeValue: "KINGS-COURT-VIP-1847-A12",
        isCheckedIn: false
    )
}
