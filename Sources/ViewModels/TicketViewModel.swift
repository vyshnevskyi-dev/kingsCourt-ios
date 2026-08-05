import Foundation
import Combine

class TicketViewModel: ObservableObject {
    @Published var currentTicket: Ticket
    @Published var isCheckedIn = false
    @Published var showQRCode = false
    
    init() {
        self.currentTicket = Ticket.sampleTicket
        // Load persisted check-in state
        if UserDefaults.standard.bool(forKey: "ticketCheckedIn") {
            currentTicket.isCheckedIn = true
            isCheckedIn = true
        }
    }
    
    func checkIn() {
        isCheckedIn = true
        currentTicket.isCheckedIn = true
        UserDefaults.standard.set(true, forKey: "ticketCheckedIn")
    }
    
    func combineQRCodeValue() -> String {
        currentTicket.qrCodeValue
    }
    
    func addTicketToCalendar() {
        // Calendar integration would be implemented here
        // With EventKit properly guarded
    }
    
    func identifyVIP() -> Bool {
        [.vip, .backstage].contains(currentTicket.type)
    }
}
