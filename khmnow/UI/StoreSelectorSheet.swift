import SwiftUI

struct StoreSelectorSheet: View {
    let game: GameInfo
    let onSelect: (GameVariant, Bool) -> Void
    let onCancel: () -> Void

    @State private var rememberSelection = true
    @State private var selectedVariant: GameVariant?

    var body: some View {
        VStack(spacing: 24) {
            // Title & Subtitle
            VStack(spacing: 8) {
                Text("Choose Store")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text("Select which platform to launch \(game.title) on:")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 40) {
                // Game Art if available
                if let urlStr = game.boxArtUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Color.white.opacity(0.1)
                    }
                    .frame(width: 180, height: 270)
                    .cornerRadius(12)
                    .shadow(radius: 10)
                }

                // Grid / List of available stores
                VStack(spacing: 16) {
                    ForEach(game.variants, id: \.id) { variant in
                        Button {
                            selectedVariant = variant
                        } label: {
                            HStack {
                                Text(variant.storeName)
                                Spacer()
                                if selectedVariant?.id == variant.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(width: 280)
                            .padding(.horizontal, 16)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            Toggle("Remember my choice for this game", isOn: $rememberSelection)
                .frame(maxWidth: 360)
                .padding(.top, 10)

            // Launch / Cancel Action Buttons
            HStack(spacing: 24) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button("Launch Game") {
                    if let selected = selectedVariant {
                        onSelect(selected, rememberSelection)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(selectedVariant == nil)
            }
            .padding(.top, 16)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .frame(maxWidth: 800)
        .onAppear {
            // Pre-select the first variant by default
            selectedVariant = game.variants.first
        }
    }
}
