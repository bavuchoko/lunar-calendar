import SwiftUI
import CoreData

enum ScheduleCategoryColor {
    static let presets: [(name: String, hex: String)] = [
        ("빨강", "#E53935"),
        ("주황", "#FB8C00"),
        ("노랑", "#FDD835"),
        ("초록", "#43A047"),
        ("파랑", "#1E88E5"),
        ("남색", "#3949AB"),
        ("보라", "#8E24AA"),
        ("분홍", "#D81B60"),
        ("회색", "#757575")
    ]

    static func color(from hex: String?) -> Color {
        guard let hex, let color = Color(hex: hex) else {
            return KanbanTheme.bodyText
        }
        return color
    }

    static func hex(from color: Color) -> String {
        color.toHex() ?? "#1E88E5"
    }

    static func contrastingTextColor(for background: Color) -> Color {
        guard let luminance = background.relativeLuminance else {
            return .primary
        }
        return luminance > 0.62 ? Color.black.opacity(0.85) : Color.white
    }

    static func tagStyle(hex: String?) -> (background: Color, foreground: Color)? {
        guard let hex, !hex.isEmpty else { return nil }
        let background = color(from: hex)
        return (background, contrastingTextColor(for: background))
    }
}

struct TagChipView: View {
    let text: String
    var hex: String? = nil
    var fontSize: CGFloat = 11
    var compact: Bool = false

    var body: some View {
        if let style = ScheduleCategoryColor.tagStyle(hex: hex) {
            Text(text)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(style.foreground)
                .padding(.horizontal, compact ? 4 : 8)
                .padding(.vertical, compact ? 2 : 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(style.background)
                .clipShape(RoundedRectangle(cornerRadius: compact ? 3 : 6, style: .continuous))
                .lineLimit(1)
        } else {
            Text(text)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }
}

extension Schedule {
    var categoryDisplayColor: Color {
        ScheduleCategoryColor.color(from: category?.colorHex)
    }

    var categoryDisplayName: String? {
        category?.name
    }

    var cardPrimaryTag: String {
        if let name = categoryDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !name.isEmpty {
            return name
        }
        if repeatRule != nil || repeatId != nil { return "반복" }
        return "일정"
    }

    var cardTagHex: String? {
        category?.colorHex
    }

    var cardSecondaryTag: String? {
        alertEnabled ? "알림" : nil
    }
}

extension Color {
    init?(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "#", with: "")

        guard sanitized.count == 6, let value = UInt64(sanitized, radix: 16) else {
            return nil
        }

        let red = Double((value & 0xFF0000) >> 16) / 255
        let green = Double((value & 0x00FF00) >> 8) / 255
        let blue = Double(value & 0x0000FF) / 255
        self.init(red: red, green: green, blue: blue)
    }

    func toHex() -> String? {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }
        return String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
        #else
        return nil
        #endif
    }

    var relativeLuminance: Double? {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }

        func adjust(_ component: CGFloat) -> Double {
            let c = Double(component)
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }

        let r = adjust(red)
        let g = adjust(green)
        let b = adjust(blue)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
        #else
        return nil
        #endif
    }
}
