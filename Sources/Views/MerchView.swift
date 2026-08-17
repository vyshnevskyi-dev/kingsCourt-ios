import SwiftUI

struct MerchView: View {
    @EnvironmentObject var merchViewModel: MerchViewModel
    @State private var showCart = false
    @State private var showDetail: MerchItem?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    categoryPicker
                    
                    ForEach(merchViewModel.filteredItems) { item in
                        MerchItemRow(item: item)
                            .onTapGesture {
                                showDetail = item
                            }
                    }
                }
                .padding(.horizontal)
            }
            .background(Theme.backgroundColor)
            .navigationTitle("Merch")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCart = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bag.fill")
                            if !merchViewModel.cart.isEmpty {
                                Text("\(merchViewModel.cart.count)")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Theme.primaryColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showCart) {
                MerchCartView()
            }
            .sheet(item: $showDetail) { item in
                MerchDetailView(item: item)
            }
        }
    }
    
    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach([MerchItem.MerchCategory.apparel, .accessories, .collectibles], id: \.self) { category in
                    Button {
                        withAnimation {
                            merchViewModel.selectedCategory = category
                        }
                    } label: {
                        Text(category.rawValue)
                            .font(.subheadline.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(merchViewModel.selectedCategory == category ? Theme.primaryColor : Theme.cardBackground)
                            .foregroundColor(merchViewModel.selectedCategory == category ? .white : Theme.secondaryColor)
                            .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    struct MerchItemRow: View {
        let item: MerchItem
        
        var body: some View {
            HStack(spacing: 12) {
                Text(item.emoji)
                    .font(.system(size: 32))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                    Text(item.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                Text(String(format: "$%.0f", item.price))
                    .font(.headline)
                    .foregroundColor(Theme.primaryColor)
            }
            .padding()
            .background(Theme.cardBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
    }
}
