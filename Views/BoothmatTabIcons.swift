// BoothmatTabIcons.swift
// Boothmate — 하단 탭바 아이콘 4종 (사전 / 파일 / 메모 / GM)
// 업데이트: SVG 기반 커스텀 아이콘으로 교체

import SwiftUI

// MARK: - 공통 Color hex 이니셜라이저
extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        self.init(
            red:   Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8)  & 0xFF) / 255,
            blue:  Double( v        & 0xFF) / 255
        )
    }
}

// MARK: - 1. 사전 아이콘 (SVG 기반 - stroke)
struct DictionaryTabIcon: View {
    var isSelected: Bool
    var iconSize: CGFloat = 22
    
    var body: some View {
        CustomDictionaryIcon()
            .stroke(isSelected ? Color(red: 0.2, green: 0.5, blue: 1.0) : .gray.opacity(0.6), lineWidth: 2.0)
            .frame(width: iconSize, height: iconSize)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - 2. 파일 아이콘 (SVG 기반 - stroke)
struct FileTabIcon: View {
    var isSelected: Bool
    var iconSize: CGFloat = 22
    
    var body: some View {
        CustomFolderIcon()
            .stroke(isSelected ? Color(red: 1.0, green: 0.5, blue: 0.2) : .gray.opacity(0.6), lineWidth: 2.0)
            .frame(width: iconSize, height: iconSize)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - 3. 메모 아이콘 (SVG 기반 - stroke)
struct MemoTabIcon: View {
    var isSelected: Bool
    var iconSize: CGFloat = 22
    
    var body: some View {
        CustomMemoIcon()
            .stroke(isSelected ? Color(red: 0.4, green: 0.75, blue: 0.4) : .gray.opacity(0.6), lineWidth: 2.0)
            .frame(width: iconSize, height: iconSize)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - 4. GM 아이콘 (SVG 기반 - stroke)
struct GMTabIcon: View {
    var isSelected: Bool
    var iconSize: CGFloat = 22
    
    var body: some View {
        CustomGMIcon()
            .stroke(isSelected ? Color(red: 0.8, green: 0.3, blue: 0.7) : .gray.opacity(0.6), lineWidth: 2.0)
            .frame(width: iconSize, height: iconSize)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - SVG Shape Definitions (원본 SVG 정확 변환)

// Dictionary Icon Shape - 새로운 dictionary.svg 그대로
struct CustomDictionaryIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        let scaleX = width / 24.0
        let scaleY = height / 24.0
        
        // Main book body (stroke path)
        path.move(to: CGPoint(x: 4 * scaleX, y: 8 * scaleY))
        path.addCurve(to: CGPoint(x: 4.87868 * scaleX, y: 2.87868 * scaleY),
                     control1: CGPoint(x: 4 * scaleX, y: 5.17157 * scaleY),
                     control2: CGPoint(x: 4 * scaleX, y: 3.75736 * scaleY))
        path.addCurve(to: CGPoint(x: 10 * scaleX, y: 2 * scaleY),
                     control1: CGPoint(x: 5.75736 * scaleX, y: 2 * scaleY),
                     control2: CGPoint(x: 7.17157 * scaleX, y: 2 * scaleY))
        path.addLine(to: CGPoint(x: 14 * scaleX, y: 2 * scaleY))
        path.addCurve(to: CGPoint(x: 19.1213 * scaleX, y: 2.87868 * scaleY),
                     control1: CGPoint(x: 16.8284 * scaleX, y: 2 * scaleY),
                     control2: CGPoint(x: 18.2426 * scaleX, y: 2 * scaleY))
        path.addCurve(to: CGPoint(x: 20 * scaleX, y: 8 * scaleY),
                     control1: CGPoint(x: 20 * scaleX, y: 3.75736 * scaleY),
                     control2: CGPoint(x: 20 * scaleX, y: 5.17157 * scaleY))
        path.addLine(to: CGPoint(x: 20 * scaleX, y: 16 * scaleY))
        path.addCurve(to: CGPoint(x: 19.1213 * scaleX, y: 21.1213 * scaleY),
                     control1: CGPoint(x: 20 * scaleX, y: 18.8284 * scaleY),
                     control2: CGPoint(x: 20 * scaleX, y: 20.2426 * scaleY))
        path.addCurve(to: CGPoint(x: 14 * scaleX, y: 22 * scaleY),
                     control1: CGPoint(x: 18.2426 * scaleX, y: 22 * scaleY),
                     control2: CGPoint(x: 16.8284 * scaleX, y: 22 * scaleY))
        path.addLine(to: CGPoint(x: 10 * scaleX, y: 22 * scaleY))
        path.addCurve(to: CGPoint(x: 4.87868 * scaleX, y: 21.1213 * scaleY),
                     control1: CGPoint(x: 7.17157 * scaleX, y: 22 * scaleY),
                     control2: CGPoint(x: 5.75736 * scaleX, y: 22 * scaleY))
        path.addCurve(to: CGPoint(x: 4 * scaleX, y: 16 * scaleY),
                     control1: CGPoint(x: 4 * scaleX, y: 20.2426 * scaleY),
                     control2: CGPoint(x: 4 * scaleX, y: 18.8284 * scaleY))
        path.addLine(to: CGPoint(x: 4 * scaleX, y: 8 * scaleY))
        path.closeSubpath()
        
        // Page fold line (opacity 0.5 in original)
        path.move(to: CGPoint(x: 19.8978 * scaleX, y: 16 * scaleY))
        path.addLine(to: CGPoint(x: 7.89778 * scaleX, y: 16 * scaleY))
        path.addCurve(to: CGPoint(x: 6.12132 * scaleX, y: 16.1022 * scaleY),
                     control1: CGPoint(x: 6.96781 * scaleX, y: 16 * scaleY),
                     control2: CGPoint(x: 6.50282 * scaleX, y: 16 * scaleY))
        path.addCurve(to: CGPoint(x: 4 * scaleX, y: 18.2235 * scaleY),
                     control1: CGPoint(x: 5.08604 * scaleX, y: 16.3796 * scaleY),
                     control2: CGPoint(x: 4.2774 * scaleX, y: 17.1883 * scaleY))
        
        // Header line (opacity 0.5 in original)
        path.move(to: CGPoint(x: 8 * scaleX, y: 7 * scaleY))
        path.addLine(to: CGPoint(x: 16 * scaleX, y: 7 * scaleY))
        
        // Text line (opacity 0.5 in original)
        path.move(to: CGPoint(x: 8 * scaleX, y: 10.5 * scaleY))
        path.addLine(to: CGPoint(x: 13 * scaleX, y: 10.5 * scaleY))
        
        return path
    }
}

// Folder Icon Shape - 원본 folder.svg 그대로
struct CustomFolderIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        let scaleX = width / 24.0
        let scaleY = height / 24.0
        
        // Folder main body (stroke 방식으로 변환)
        path.move(to: CGPoint(x: 2 * scaleX, y: 6.94975 * scaleY))
        path.addCurve(to: CGPoint(x: 2.06935 * scaleX, y: 5.25839 * scaleY),
                     control1: CGPoint(x: 2 * scaleX, y: 6.06722 * scaleY),
                     control2: CGPoint(x: 2 * scaleX, y: 5.62595 * scaleY))
        path.addCurve(to: CGPoint(x: 5.25839 * scaleX, y: 2.06935 * scaleY),
                     control1: CGPoint(x: 2.37464 * scaleX, y: 3.64031 * scaleY),
                     control2: CGPoint(x: 3.64031 * scaleX, y: 2.37464 * scaleY))
        path.addCurve(to: CGPoint(x: 6.94975 * scaleX, y: 2 * scaleY),
                     control1: CGPoint(x: 5.62595 * scaleX, y: 2 * scaleY),
                     control2: CGPoint(x: 6.06722 * scaleX, y: 2 * scaleY))
        path.addCurve(to: CGPoint(x: 7.71557 * scaleX, y: 2.01738 * scaleY),
                     control1: CGPoint(x: 7.33642 * scaleX, y: 2 * scaleY),
                     control2: CGPoint(x: 7.52976 * scaleX, y: 2 * scaleY))
        path.addCurve(to: CGPoint(x: 9.89594 * scaleX, y: 2.92051 * scaleY),
                     control1: CGPoint(x: 8.51665 * scaleX, y: 2.09229 * scaleY),
                     control2: CGPoint(x: 9.27652 * scaleX, y: 2.40704 * scaleY))
        path.addCurve(to: CGPoint(x: 10.4497 * scaleX, y: 3.44975 * scaleY),
                     control1: CGPoint(x: 10.0396 * scaleX, y: 3.03961 * scaleY),
                     control2: CGPoint(x: 10.1763 * scaleX, y: 3.17633 * scaleY))
        path.addLine(to: CGPoint(x: 11 * scaleX, y: 4 * scaleY))
        path.addCurve(to: CGPoint(x: 12.7121 * scaleX, y: 5.49543 * scaleY),
                     control1: CGPoint(x: 11.8158 * scaleX, y: 4.81578 * scaleY),
                     control2: CGPoint(x: 12.2237 * scaleX, y: 5.22367 * scaleY))
        path.addCurve(to: CGPoint(x: 13.5604 * scaleX, y: 5.84678 * scaleY),
                     control1: CGPoint(x: 12.9804 * scaleX, y: 5.64471 * scaleY),
                     control2: CGPoint(x: 13.2651 * scaleX, y: 5.7626 * scaleY))
        path.addCurve(to: CGPoint(x: 15.8284 * scaleX, y: 6 * scaleY),
                     control1: CGPoint(x: 14.0979 * scaleX, y: 6 * scaleY),
                     control2: CGPoint(x: 14.6747 * scaleX, y: 6 * scaleY))
        path.addLine(to: CGPoint(x: 16.2021 * scaleX, y: 6 * scaleY))
        path.addCurve(to: CGPoint(x: 21.0062 * scaleX, y: 6.76946 * scaleY),
                     control1: CGPoint(x: 18.8345 * scaleX, y: 6 * scaleY),
                     control2: CGPoint(x: 20.1506 * scaleX, y: 6 * scaleY))
        path.addCurve(to: CGPoint(x: 21.2305 * scaleX, y: 6.99383 * scaleY),
                     control1: CGPoint(x: 21.0849 * scaleX, y: 6.84024 * scaleY),
                     control2: CGPoint(x: 21.1598 * scaleX, y: 6.91514 * scaleY))
        path.addCurve(to: CGPoint(x: 22 * scaleX, y: 11.7979 * scaleY),
                     control1: CGPoint(x: 22 * scaleX, y: 7.84935 * scaleY),
                     control2: CGPoint(x: 22 * scaleX, y: 9.16554 * scaleY))
        path.addLine(to: CGPoint(x: 22 * scaleX, y: 14 * scaleY))
        path.addCurve(to: CGPoint(x: 20.8284 * scaleX, y: 20.8284 * scaleY),
                     control1: CGPoint(x: 22 * scaleX, y: 17.7712 * scaleY),
                     control2: CGPoint(x: 22 * scaleX, y: 19.6569 * scaleY))
        path.addCurve(to: CGPoint(x: 14 * scaleX, y: 22 * scaleY),
                     control1: CGPoint(x: 19.6569 * scaleX, y: 22 * scaleY),
                     control2: CGPoint(x: 17.7712 * scaleX, y: 22 * scaleY))
        path.addLine(to: CGPoint(x: 10 * scaleX, y: 22 * scaleY))
        path.addCurve(to: CGPoint(x: 3.17157 * scaleX, y: 20.8284 * scaleY),
                     control1: CGPoint(x: 6.22876 * scaleX, y: 22 * scaleY),
                     control2: CGPoint(x: 4.34315 * scaleX, y: 22 * scaleY))
        path.addCurve(to: CGPoint(x: 2 * scaleX, y: 14 * scaleY),
                     control1: CGPoint(x: 2 * scaleX, y: 19.6569 * scaleY),
                     control2: CGPoint(x: 2 * scaleX, y: 17.7712 * scaleY))
        path.addLine(to: CGPoint(x: 2 * scaleX, y: 6.94975 * scaleY))
        path.closeSubpath()
        
        // Inner line (from original stroke path)
        path.move(to: CGPoint(x: 18 * scaleX, y: 10 * scaleY))
        path.addLine(to: CGPoint(x: 13 * scaleX, y: 10 * scaleY))
        
        return path
    }
}

// Memo Icon Shape - 원본 memo.svg 그대로
struct CustomMemoIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        let scaleX = width / 24.0
        let scaleY = height / 24.0
        
        // Main clipboard body
        path.move(to: CGPoint(x: 20 * scaleX, y: 8.25 * scaleY))
        path.addLine(to: CGPoint(x: 20 * scaleX, y: 18 * scaleY))
        path.addCurve(to: CGPoint(x: 18.21 * scaleX, y: 22 * scaleY),
                     control1: CGPoint(x: 20 * scaleX, y: 21 * scaleY),
                     control2: CGPoint(x: 20 * scaleX, y: 22 * scaleY))
        path.addLine(to: CGPoint(x: 16 * scaleX, y: 22 * scaleY))
        path.addLine(to: CGPoint(x: 8 * scaleX, y: 22 * scaleY))
        path.addCurve(to: CGPoint(x: 4 * scaleX, y: 18 * scaleY),
                     control1: CGPoint(x: 5.79 * scaleX, y: 22 * scaleY),
                     control2: CGPoint(x: 4 * scaleX, y: 21 * scaleY))
        path.addLine(to: CGPoint(x: 4 * scaleX, y: 8.25 * scaleY))
        path.addCurve(to: CGPoint(x: 8 * scaleX, y: 4.25 * scaleY),
                     control1: CGPoint(x: 4 * scaleX, y: 5 * scaleY),
                     control2: CGPoint(x: 5.79 * scaleX, y: 4.25 * scaleY))
        path.addCurve(to: CGPoint(x: 8.65997 * scaleX, y: 5.84 * scaleY),
                     control1: CGPoint(x: 8 * scaleX, y: 4.87 * scaleY),
                     control2: CGPoint(x: 8.24997 * scaleX, y: 5.43 * scaleY))
        path.addCurve(to: CGPoint(x: 10.25 * scaleX, y: 6.5 * scaleY),
                     control1: CGPoint(x: 9.06997 * scaleX, y: 6.25 * scaleY),
                     control2: CGPoint(x: 9.63 * scaleX, y: 6.5 * scaleY))
        path.addLine(to: CGPoint(x: 13.75 * scaleX, y: 6.5 * scaleY))
        path.addCurve(to: CGPoint(x: 16 * scaleX, y: 4.25 * scaleY),
                     control1: CGPoint(x: 14.99 * scaleX, y: 6.5 * scaleY),
                     control2: CGPoint(x: 16 * scaleX, y: 5.49 * scaleY))
        path.addCurve(to: CGPoint(x: 20 * scaleX, y: 8.25 * scaleY),
                     control1: CGPoint(x: 18.21 * scaleX, y: 4.25 * scaleY),
                     control2: CGPoint(x: 20 * scaleX, y: 5 * scaleY))
        path.closeSubpath()
        
        // Clip section
        path.move(to: CGPoint(x: 16 * scaleX, y: 4.25 * scaleY))
        path.addCurve(to: CGPoint(x: 15.34 * scaleX, y: 2.66 * scaleY),
                     control1: CGPoint(x: 16 * scaleX, y: 3.63 * scaleY),
                     control2: CGPoint(x: 15.75 * scaleX, y: 3.07 * scaleY))
        path.addCurve(to: CGPoint(x: 13.75 * scaleX, y: 2 * scaleY),
                     control1: CGPoint(x: 14.93 * scaleX, y: 2.25 * scaleY),
                     control2: CGPoint(x: 14.37 * scaleX, y: 2 * scaleY))
        path.addLine(to: CGPoint(x: 10.25 * scaleX, y: 2 * scaleY))
        path.addCurve(to: CGPoint(x: 8 * scaleX, y: 4.25 * scaleY),
                     control1: CGPoint(x: 9.01 * scaleX, y: 2 * scaleY),
                     control2: CGPoint(x: 8 * scaleX, y: 3.01 * scaleY))
        path.addCurve(to: CGPoint(x: 8.65997 * scaleX, y: 5.84 * scaleY),
                     control1: CGPoint(x: 8 * scaleX, y: 4.87 * scaleY),
                     control2: CGPoint(x: 8.24997 * scaleX, y: 5.43 * scaleY))
        path.addCurve(to: CGPoint(x: 10.25 * scaleX, y: 6.5 * scaleY),
                     control1: CGPoint(x: 9.06997 * scaleX, y: 6.25 * scaleY),
                     control2: CGPoint(x: 9.63 * scaleX, y: 6.5 * scaleY))
        path.addLine(to: CGPoint(x: 13.75 * scaleX, y: 6.5 * scaleY))
        path.addCurve(to: CGPoint(x: 16 * scaleX, y: 4.25 * scaleY),
                     control1: CGPoint(x: 14.99 * scaleX, y: 6.5 * scaleY),
                     control2: CGPoint(x: 16 * scaleX, y: 5.49 * scaleY))
        path.closeSubpath()
        
        // Lines (from original stroke paths)
        path.move(to: CGPoint(x: 8 * scaleX, y: 13 * scaleY))
        path.addLine(to: CGPoint(x: 12 * scaleX, y: 13 * scaleY))
        
        path.move(to: CGPoint(x: 8 * scaleX, y: 17 * scaleY))
        path.addLine(to: CGPoint(x: 16 * scaleX, y: 17 * scaleY))
        
        return path
    }
}

// GM Icon Shape - 원본 GM.svg 그대로
struct CustomGMIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        let scaleX = width / 24.0
        let scaleY = height / 24.0
        
        // Calendar rings
        path.move(to: CGPoint(x: 8 * scaleX, y: 2 * scaleY))
        path.addLine(to: CGPoint(x: 8 * scaleX, y: 5 * scaleY))
        
        path.move(to: CGPoint(x: 16 * scaleX, y: 2 * scaleY))
        path.addLine(to: CGPoint(x: 16 * scaleX, y: 5 * scaleY))
        
        // Calendar main body
        path.move(to: CGPoint(x: 21 * scaleX, y: 8.5 * scaleY))
        path.addLine(to: CGPoint(x: 21 * scaleX, y: 13.63 * scaleY))
        path.addCurve(to: CGPoint(x: 20.11 * scaleX, y: 12.92 * scaleY),
                     control1: CGPoint(x: 20.11 * scaleX, y: 12.92 * scaleY),
                     control2: CGPoint(x: 20.11 * scaleX, y: 12.92 * scaleY))
        path.addCurve(to: CGPoint(x: 17.75 * scaleX, y: 12.5 * scaleY),
                     control1: CGPoint(x: 18.98 * scaleX, y: 12.5 * scaleY),
                     control2: CGPoint(x: 18.98 * scaleX, y: 12.5 * scaleY))
        path.addCurve(to: CGPoint(x: 14.47 * scaleX, y: 13.66 * scaleY),
                     control1: CGPoint(x: 16.52 * scaleX, y: 12.5 * scaleY),
                     control2: CGPoint(x: 15.37 * scaleX, y: 12.93 * scaleY))
        path.addCurve(to: CGPoint(x: 12.5 * scaleX, y: 17.75 * scaleY),
                     control1: CGPoint(x: 13.26 * scaleX, y: 14.61 * scaleY),
                     control2: CGPoint(x: 12.5 * scaleX, y: 16.1 * scaleY))
        path.addCurve(to: CGPoint(x: 13.26 * scaleX, y: 20.45 * scaleY),
                     control1: CGPoint(x: 12.5 * scaleX, y: 18.73 * scaleY),
                     control2: CGPoint(x: 12.78 * scaleX, y: 19.67 * scaleY))
        path.addCurve(to: CGPoint(x: 14.68 * scaleX, y: 22 * scaleY),
                     control1: CGPoint(x: 13.63 * scaleX, y: 21.06 * scaleY),
                     control2: CGPoint(x: 14.11 * scaleX, y: 21.59 * scaleY))
        path.addLine(to: CGPoint(x: 8 * scaleX, y: 22 * scaleY))
        path.addCurve(to: CGPoint(x: 3 * scaleX, y: 17 * scaleY),
                     control1: CGPoint(x: 4.5 * scaleX, y: 22 * scaleY),
                     control2: CGPoint(x: 3 * scaleX, y: 20 * scaleY))
        path.addLine(to: CGPoint(x: 3 * scaleX, y: 8.5 * scaleY))
        path.addCurve(to: CGPoint(x: 8 * scaleX, y: 3.5 * scaleY),
                     control1: CGPoint(x: 3 * scaleX, y: 5.5 * scaleY),
                     control2: CGPoint(x: 4.5 * scaleX, y: 3.5 * scaleY))
        path.addLine(to: CGPoint(x: 16 * scaleX, y: 3.5 * scaleY))
        path.addCurve(to: CGPoint(x: 21 * scaleX, y: 8.5 * scaleY),
                     control1: CGPoint(x: 19.5 * scaleX, y: 3.5 * scaleY),
                     control2: CGPoint(x: 21 * scaleX, y: 5.5 * scaleY))
        path.closeSubpath()
        
        // Calendar lines
        path.move(to: CGPoint(x: 7 * scaleX, y: 11 * scaleY))
        path.addLine(to: CGPoint(x: 13 * scaleX, y: 11 * scaleY))
        
        path.move(to: CGPoint(x: 7 * scaleX, y: 16 * scaleY))
        path.addLine(to: CGPoint(x: 9.62 * scaleX, y: 16 * scaleY))
        
        // Clock circle
        path.move(to: CGPoint(x: 23 * scaleX, y: 17.75 * scaleY))
        path.addCurve(to: CGPoint(x: 22.24 * scaleX, y: 20.45 * scaleY),
                     control1: CGPoint(x: 23 * scaleX, y: 18.73 * scaleY),
                     control2: CGPoint(x: 22.72 * scaleX, y: 19.67 * scaleY))
        path.addCurve(to: CGPoint(x: 21.2 * scaleX, y: 21.69 * scaleY),
                     control1: CGPoint(x: 21.96 * scaleX, y: 20.93 * scaleY),
                     control2: CGPoint(x: 21.61 * scaleX, y: 21.35 * scaleY))
        path.addCurve(to: CGPoint(x: 17.75 * scaleX, y: 23 * scaleY),
                     control1: CGPoint(x: 20.28 * scaleX, y: 22.51 * scaleY),
                     control2: CGPoint(x: 19.08 * scaleX, y: 23 * scaleY))
        path.addCurve(to: CGPoint(x: 14.68 * scaleX, y: 22 * scaleY),
                     control1: CGPoint(x: 16.6 * scaleX, y: 23 * scaleY),
                     control2: CGPoint(x: 15.54 * scaleX, y: 22.63 * scaleY))
        path.addCurve(to: CGPoint(x: 13.26 * scaleX, y: 20.45 * scaleY),
                     control1: CGPoint(x: 14.11 * scaleX, y: 21.59 * scaleY),
                     control2: CGPoint(x: 13.63 * scaleX, y: 21.06 * scaleY))
        path.addCurve(to: CGPoint(x: 12.5 * scaleX, y: 17.75 * scaleY),
                     control1: CGPoint(x: 12.78 * scaleX, y: 19.67 * scaleY),
                     control2: CGPoint(x: 12.5 * scaleX, y: 18.73 * scaleY))
        path.addCurve(to: CGPoint(x: 14.47 * scaleX, y: 13.66 * scaleY),
                     control1: CGPoint(x: 12.5 * scaleX, y: 16.1 * scaleY),
                     control2: CGPoint(x: 13.26 * scaleX, y: 14.61 * scaleY))
        path.addCurve(to: CGPoint(x: 17.75 * scaleX, y: 12.5 * scaleY),
                     control1: CGPoint(x: 15.37 * scaleX, y: 12.93 * scaleY),
                     control2: CGPoint(x: 16.52 * scaleX, y: 12.5 * scaleY))
        path.addCurve(to: CGPoint(x: 21 * scaleX, y: 13.63 * scaleY),
                     control1: CGPoint(x: 18.98 * scaleX, y: 12.5 * scaleY),
                     control2: CGPoint(x: 20.11 * scaleX, y: 12.92 * scaleY))
        path.addCurve(to: CGPoint(x: 23 * scaleX, y: 17.75 * scaleY),
                     control1: CGPoint(x: 22.22 * scaleX, y: 14.59 * scaleY),
                     control2: CGPoint(x: 23 * scaleX, y: 16.08 * scaleY))
        path.closeSubpath()
        
        // Star shape in clock
        path.move(to: CGPoint(x: 17.75 * scaleX, y: 20.25 * scaleY))
        path.addCurve(to: CGPoint(x: 20.25 * scaleX, y: 17.75 * scaleY),
                     control1: CGPoint(x: 17.75 * scaleX, y: 18.87 * scaleY),
                     control2: CGPoint(x: 18.87 * scaleX, y: 17.75 * scaleY))
        path.addCurve(to: CGPoint(x: 17.75 * scaleX, y: 15.25 * scaleY),
                     control1: CGPoint(x: 18.87 * scaleX, y: 17.75 * scaleY),
                     control2: CGPoint(x: 17.75 * scaleX, y: 16.63 * scaleY))
        path.addCurve(to: CGPoint(x: 15.25 * scaleX, y: 17.75 * scaleY),
                     control1: CGPoint(x: 17.75 * scaleX, y: 16.63 * scaleY),
                     control2: CGPoint(x: 16.63 * scaleX, y: 17.75 * scaleY))
        path.addCurve(to: CGPoint(x: 17.75 * scaleX, y: 20.25 * scaleY),
                     control1: CGPoint(x: 16.63 * scaleX, y: 17.75 * scaleY),
                     control2: CGPoint(x: 17.75 * scaleX, y: 18.87 * scaleY))
        path.closeSubpath()
        
        return path
    }
}
