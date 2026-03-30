import SwiftUI

/// 공휴일·일정 목록 칸반 UI 공통 색상
enum KanbanTheme {
    static let background = Color(red: 0.93, green: 0.94, blue: 0.97)
    static let titleNavy = Color(red: 0.11, green: 0.16, blue: 0.28)
    static let bodyText = Color(red: 0.12, green: 0.16, blue: 0.23)

    static let tagPalette: [Color] = [
        Color(red: 1.0, green: 0.82, blue: 0.35),
        Color(red: 0.35, green: 0.62, blue: 1.0),
        Color(red: 0.62, green: 0.45, blue: 0.95),
        Color(red: 0.28, green: 0.78, blue: 0.88),
        Color(red: 1.0, green: 0.45, blue: 0.65)
    ]

    static let secondaryTagFill = Color(red: 0.88, green: 0.92, blue: 1.0)
    static let secondaryTagForeground = Color(red: 0.25, green: 0.38, blue: 0.65)
}
