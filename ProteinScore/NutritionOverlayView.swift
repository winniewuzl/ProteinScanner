import SwiftUI

struct NutritionOverlayView: View {
    let nutritionData: NutritionData

    private var score: ProteinScore {
        ProteinScore(ratio: nutritionData.ratio)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 8) {
                // Large ratio number
                Text(String(format: "%.1f", nutritionData.ratio))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Small label
                Text("g protein / 100 cal")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))

                // Color dot + rating
                HStack(spacing: 8) {
                    Circle()
                        .fill(score.color)
                        .frame(width: 12, height: 12)

                    Text(score.label)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.top, 12)
            }
            .padding(.vertical, 32)
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.black.opacity(0.7))
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 60)
        }
    }
}

#Preview {
    ZStack {
        Color.gray
        NutritionOverlayView(nutritionData: NutritionData(calories: 100, protein: 12))
    }
}
