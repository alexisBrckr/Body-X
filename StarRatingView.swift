import SwiftUI

struct StarRatingView: View {
    let rating: Int
    var size: CGFloat = 14
    var color: Color = .yellow

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundColor(i <= rating ? color : Color(.systemGray4))
            }
        }
    }
}

struct StarPickerView: View {
    @Binding var rating: Int
    var size: CGFloat = 28

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { i in
                Image(systemName: i <= rating ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundColor(i <= rating ? .yellow : Color(.systemGray4))
                    .onTapGesture { rating = i }
                    .animation(.easeInOut(duration: 0.15), value: rating)
            }
        }
    }
}
