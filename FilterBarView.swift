import SwiftUI

struct FilterBarView: View {
    @Binding var selectedSort: DealsSortOption
    @Binding var isGridView: Bool

    var body: some View {
        HStack {
            Picker("Sort", selection: $selectedSort) {
                ForEach(DealsSortOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(MenuPickerStyle())
            
            Spacer()
            
            Button(action: {
                isGridView.toggle()
            }) {
                Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                    .foregroundColor(.blue)
            }
            .accessibilityLabel(isGridView ? "Switch to list view" : "Switch to grid view")
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}
