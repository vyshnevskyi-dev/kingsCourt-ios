import SwiftUI
import CoreImage.CIFilterBuiltins

struct TicketView: View {
    @EnvironmentObject var ticketViewModel: TicketViewModel
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ticketCard
                    
                    VIPAccessView(isVIP: ticketViewModel.identifyVIP())
                    
                    checkInButton
                    
                    shareTicketButton
                }
                .padding()
            }
            .background(Theme.backgroundColor)
            .navigationTitle("My Ticket")
        }
    }
    
    private var ticketCard: some View {
        VStack(spacing: 0) {
            // Ticket top
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(AppConstants.tournamentName)
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Text(ticketViewModel.currentTicket.type.rawValue)
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(6)
                }
                
                Text(AppConstants.tournamentDate)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                
                Text(AppConstants.venueName)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding()
            .background(Theme.primaryColor)
            
            // Ticket middle with perforation effect
            HStack {
                Text("Sec \(ticketViewModel.currentTicket.section) • Row \(ticketViewModel.currentTicket.row) • Seat \(ticketViewModel.currentTicket.seat)")
                    .font(.subheadline.bold())
                    .foregroundColor(Theme.secondaryColor)
                Spacer()
                Text(ticketViewModel.currentTicket.holderName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Theme.cardBackground)
            
            // Ticket bottom with QR
            VStack(spacing: 12) {
                if ticketViewModel.showQRCode {
                    QRCodeView(text: ticketViewModel.combineQRCodeValue())
                        .frame(width: 160, height: 160)
                        .padding(.vertical, 8)
                } else {
                    Button {
                        withAnimation {
                            ticketViewModel.showQRCode = true
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 40))
                                .foregroundColor(Theme.primaryColor)
                            Text("Show QR Code")
                                .font(.headline)
                                .foregroundColor(Theme.primaryColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                }
                
                Text("\(ticketViewModel.currentTicket.ticketNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Theme.cardBackground)
        }
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
        .padding(.horizontal)
    }
    
    private var checkInButton: some View {
        Button {
            ticketViewModel.checkIn()
        } label: {
            HStack {
                Image(systemName: ticketViewModel.isCheckedIn ? "checkmark.seal.fill" : "checkmark.seal")
                Text(ticketViewModel.isCheckedIn ? "Checked In" : "Check In Now")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(ticketViewModel.isCheckedIn ? Color.green : Theme.primaryColor)
            .cornerRadius(12)
        }
        .disabled(ticketViewModel.isCheckedIn)
        .padding(.horizontal)
    }
    
    private var shareTicketButton: some View {
        ShareLink(item: generateTicketShareText()) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text("Share Ticket")
            }
            .font(.headline)
            .foregroundColor(Theme.secondaryColor)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    private func generateTicketShareText() -> String {
        let ticket = ticketViewModel.currentTicket
        return "I'm attending \(ticket.eventName) on \(ticket.eventDate.formatted(.dateTime))! My seat: \(ticket.section) Row \(ticket.row) Seat \(ticket.seat). #KingsCourt"
    }
    
    struct QRCodeView: View {
        let text: String
        
        func generateQRCode(from text: String) -> UIImage {
            let context = CIContext()
            let filter = CIFilter.qrCodeGenerator()
            filter.message = Data(text.utf8)
            
            if let output = filter.outputImage {
                let scaled = output.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
                if let cgImage = context.createCGImage(scaled, from: scaled.extent) {
                    return UIImage(cgImage: cgImage)
                }
            }
            
            return UIImage(systemName: "qrcode") ?? UIImage()
        }
        
        var body: some View {
            Image(uiImage: generateQRCode(from: text))
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        }
    }
    
    struct VIPAccessView: View {
        let isVIP: Bool
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: isVIP ? "crown.fill" : "crown")
                    .font(.title)
                    .foregroundColor(isVIP ? .yellow : .gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(isVIP ? "VIP Access" : "Standard Access")
                        .font(.headline)
                    Text(isVIP ? "Lounge access & best views" : "General admission seating")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(isVIP ? Color.yellow.opacity(0.2) : Theme.cardBackground)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isVIP ? Color.yellow : .gray.opacity(0.3), lineWidth: 1))
            .padding(.horizontal)
        }
    }
}
