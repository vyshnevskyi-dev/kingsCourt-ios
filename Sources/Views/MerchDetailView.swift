import SwiftUI

struct MerchDetailView: View {
    let item: MerchItem
    @EnvironmentObject var merchViewModel: MerchViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedSize = "M"
    @State private var quantity = 1
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: item.emoji)
                    .font(.system(size: 80))
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(Theme.secondaryColor.opacity(0.1))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.name)
                        .font(.title2.bold())
                    
                    Text(item.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "$%.0f", item.price))
                        .font(.title.bold())
                        .foregroundColor(Theme.primaryColor)
                }
                .padding(.horizontal)
                
                if !item.sizesAvailable.isEmpty && item.sizesAvailable != ["One Size"] {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Size")
                            .font(.headline)
                        
                        HStack(spacing: 8) {
                            ForEach(item.sizesAvailable, id: \.self) { size in
                                Button {
                                    selectedSize = size
                                } label: {
                                    Text(size)
                                        .font(.subheadline.bold())
                                        .frame(width: 44, height: 44)
                                        .background(selectedSize == size ? Theme.primaryColor : Theme.cardBackground)
                                        .foregroundColor(selectedSize == size ? .white : Theme.secondaryColor)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                HStack(spacing: 20) {
                    Button {
                        if quantity > 1 { quantity -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title)
                            .foregroundColor(Theme.secondaryColor)
                    }
                    
                    Text("\(quantity)")
                        .font(.title2.bold())
                        .frame(minWidth: 40)
                    
                    Button {
                        quantity += 1
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundColor(Theme.primaryColor)
                    }
                }
                .padding(.vertical)
                
                Button {
                    merchViewModel.addToCart(item: item, size: item.sizesAvailable == ["One Size"] ? "One Size" : selectedSize, quantity: quantity)
                    dismiss()
                } label: {
                    Text("Add to Bag")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.primaryColor)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
            }
            .navigationTitle(item.category.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
