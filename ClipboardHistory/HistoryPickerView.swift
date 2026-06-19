import SwiftUI

struct HistoryPickerView: View {
    let items: [ClipboardItem]
    let selectedIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "doc.on.clipboard")
                    .foregroundStyle(.secondary)
                Text("クリップボード履歴")
                    .font(.headline)
                Spacer()
                Text("⌘⇧V")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if items.isEmpty {
                Text("履歴がありません")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    HistoryRowView(
                        index: index,
                        item: item,
                        isSelected: index == selectedIndex,
                        onSelect: { onSelect(index) }
                    )
                }
            }

            Divider()

            Text("↑↓ 移動　↩ 選択　⎋ 閉じる")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
        }
        .frame(width: 380)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct HistoryRowView: View {
    let index: Int
    let item: ClipboardItem
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .trailing)

            Text(item.text)
                .lineLimit(2)
                .truncationMode(.tail)
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isSelected ? Color.accentColor : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}
