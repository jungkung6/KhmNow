import SwiftUI

struct StreamKeyboardSheet: View {
    @State private var inputText: String = ""
    let onSend: (String) -> Void
    let onBackspace: () -> Void
    let onEnter: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Keyboard Input")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text("Type or dictate text to send to the game:")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            // Input Field
            TextField("Click to type or dictate...", text: $inputText)
                .textFieldStyle(.plain)
                .font(.title3)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )
                .foregroundStyle(.white)
                .frame(maxWidth: 560)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )

            // Dynamic Action Buttons
            HStack(spacing: 20) {
                Button {
                    onSend(inputText)
                    inputText = ""
                } label: {
                    Label("Send Text", systemImage: "paperplane.fill")
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(inputText.isEmpty)

                Button {
                    onBackspace()
                } label: {
                    Label("Backspace", systemImage: "delete.left")
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.bordered)
                .tint(.orange)

                Button {
                    onEnter()
                } label: {
                    Label("Enter / Return", systemImage: "return")
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.bordered)
                .tint(.blue)

                Button {
                    onDismiss()
                } label: {
                    Label("Close", systemImage: "xmark")
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .padding(.top, 10)
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
        .frame(maxWidth: 700)
    }
}
