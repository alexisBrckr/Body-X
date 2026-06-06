import SwiftUI

struct StarRatingView: View {
    let rating: Double
    var size: CGFloat = 14
    var color: Color = .yellow

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                let state = starState(for: i)
                Image(systemName: state.systemImage)
                    .font(.system(size: size))
                    .foregroundColor(state.isSelected ? color : Color(.systemGray4))
            }
        }
    }

    private func starState(for position: Int) -> StarState {
        let fullValue = Double(position)
        if rating >= fullValue {
            return .full
        }
        if rating >= fullValue - 0.5 {
            return .half
        }
        return .empty
    }
}

struct StarPickerView: View {
    @Binding var rating: Double
    var size: CGFloat = 28

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { i in
                ZStack {
                    let state = starState(for: i)
                    Image(systemName: state.systemImage)
                        .font(.system(size: size))
                        .foregroundColor(state.isSelected ? .yellow : Color(.systemGray4))

                    HStack(spacing: 0) {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                rating = Double(i) - 0.5
                            }
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                rating = Double(i)
                            }
                    }
                }
                .frame(width: size, height: size)
                .accessibilityLabel("\(RatingScale.formatted(Double(i))) étoiles")
                .animation(.easeInOut(duration: 0.15), value: rating)
            }
        }
    }

    private func starState(for position: Int) -> StarState {
        let fullValue = Double(position)
        if rating >= fullValue {
            return .full
        }
        if rating >= fullValue - 0.5 {
            return .half
        }
        return .empty
    }
}

private enum StarState {
    case empty
    case half
    case full

    var systemImage: String {
        switch self {
        case .empty: return "star"
        case .half: return "star.leadinghalf.filled"
        case .full: return "star.fill"
        }
    }

    var isSelected: Bool {
        switch self {
        case .empty: return false
        case .half, .full: return true
        }
    }
}
