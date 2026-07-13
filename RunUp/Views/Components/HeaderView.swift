import SwiftUI

/// Screen header: eyebrow + large Bebas title, optional trailing accessory. Mirrors `Header` in ui.jsx.
struct HeaderView<Trailing: View>: View {
    var eyebrow: String
    var title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                EyebrowLabel(text: eyebrow, color: RUColor.rose)
                Text(title).displayStyle(24).foregroundColor(.white)
            }
            Spacer()
            trailing
        }
        .padding(.vertical, 2)
    }
}

/// Circular first-initial avatar button, the default trailing accessory used across headers.
struct AvatarButton: View {
    var initial: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(RUColor.rose)
                .frame(width: 36, height: 36)
                .overlay(Text(initial.uppercased()).displayStyle(15).foregroundColor(.white))
        }
        .buttonStyle(PressableStyle())
    }
}

/// Back chevron button used at the top of most sub-screens.
struct BackChevronButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("‹")
                .font(.system(size: 22))
                .foregroundColor(RUColor.text2)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(PressableStyle())
    }
}

/// Frosted circular chevron used over imagery (Live Run, Recap hero).
struct FrostedBackButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("‹")
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(.black.opacity(0.45), in: Circle())
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(PressableStyle())
    }
}
