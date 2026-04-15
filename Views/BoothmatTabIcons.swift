// BoothmatTabIcons.swift
// Boothmate — 하단 탭바 아이콘 4종 (사전 / 파일 / 메모 / GM)
// 사용법: ContentView의 TabView에 바로 붙여넣기

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

// MARK: - 1. 사전 아이콘 (2단 사전 + 책갈피 + 점선)
struct DictionaryTabIcon: View {
    var isSelected: Bool
    var iconSize: CGFloat = 22
    private var sc: CGFloat { iconSize / 72 }

    var cover:  Color { isSelected ? Color(hex:"#E67E22") : Color(hex:"#D0D0D0") }
    var page:   Color { isSelected ? Color(hex:"#FFFDE7") : Color(hex:"#F2F2F2") }
    var div:    Color { isSelected ? Color(hex:"#CA6F1E") : Color(hex:"#BBBBBB") }
    var bm:     Color { isSelected ? Color(hex:"#C0392B") : Color(hex:"#BBBBBB") }
    var lLines: [Color] { isSelected
        ? [Color(hex:"#C0392B"), Color(hex:"#C0392B"), Color(hex:"#C0392B")]
        : Array(repeating: Color(hex:"#C8C8C8"), count: 3) }
    var rLines: [Color] { isSelected
        ? [Color(hex:"#2980B9"), Color(hex:"#27AE60"), Color(hex:"#8E44AD")]
        : Array(repeating: Color(hex:"#C8C8C8"), count: 3) }
    var lDots: Color { isSelected ? Color(hex:"#E8A87C") : Color(hex:"#DDDDDD") }
    var rDotColors: [Color] { isSelected
        ? [Color(hex:"#7FB9D9"), Color(hex:"#7FC99A"), Color(hex:"#B89CCE")]
        : Array(repeating: Color(hex:"#DDDDDD"), count: 3) }

    let rowYs:  [CGFloat] = [16, 33, 50]   // 굵은 줄 Y
    let dotYs:  [CGFloat] = [22, 39, 56]   // 점선 Y
    let lWs:    [CGFloat] = [18, 14, 17]   // 왼쪽 줄 폭
    let rWs:    [CGFloat] = [22, 18, 20]   // 오른쪽 줄 폭
    let dotGap: CGFloat   = 6              // 점 간격
    let dotW:   CGFloat   = 4             // 점 폭
    let dotH:   CGFloat   = 2             // 점 높이

    var body: some View {
        Canvas { ctx, _ in
            let c  = sc
            let W  = 64 * c
            let H  = 72 * c
            let cr = 4  * c

            // 클립
            var clip = Path()
            clip.move(to:    .init(x:cr,   y:0))
            clip.addLine(to: .init(x:W-cr, y:0))
            clip.addQuadCurve(to: .init(x:W,  y:cr),   control: .init(x:W, y:0))
            clip.addLine(to: .init(x:W,    y:H-cr))
            clip.addQuadCurve(to: .init(x:W-cr, y:H),  control: .init(x:W, y:H))
            clip.addLine(to: .init(x:cr,   y:H))
            clip.addQuadCurve(to: .init(x:0, y:H-cr),  control: .init(x:0, y:H))
            clip.addLine(to: .init(x:0,    y:cr))
            clip.addQuadCurve(to: .init(x:cr, y:0),    control: .init(x:0, y:0))
            clip.closeSubpath()
            ctx.clip(to: clip)

            // 표지
            ctx.fill(Path(.init(x:0, y:0, width:W, height:H)), with:.color(cover))
            // 내지
            ctx.fill(Path(roundedRect: .init(x:4*c, y:6*c, width:56*c, height:60*c), cornerRadius:2*c), with:.color(page))
            // 중앙 분리선
            ctx.fill(Path(.init(x:30*c, y:6*c, width:1.5*c, height:60*c)), with:.color(div))

            // 책갈피
            var bmp = Path()
            bmp.move(to:    .init(x:50*c, y:0))
            bmp.addLine(to: .init(x:60*c, y:0))
            bmp.addLine(to: .init(x:60*c, y:18*c))
            bmp.addLine(to: .init(x:55*c, y:13*c))
            bmp.addLine(to: .init(x:50*c, y:18*c))
            bmp.closeSubpath()
            ctx.fill(bmp, with:.color(bm))

            for (i, ry) in rowYs.enumerated() {
                // 왼쪽 굵은 줄
                ctx.fill(Path(roundedRect: .init(x:7*c, y:ry*c, width:lWs[i]*c, height:3*c), cornerRadius:1.5*c), with:.color(lLines[i]))
                // 오른쪽 굵은 줄
                ctx.fill(Path(roundedRect: .init(x:33*c, y:ry*c, width:rWs[i]*c, height:3*c), cornerRadius:1.5*c), with:.color(rLines[i]))

                // 왼쪽 점선 (3점)
                let dy = dotYs[i] * c
                for d in 0..<3 {
                    let dx = (7 + CGFloat(d) * dotGap) * c
                    ctx.fill(Path(roundedRect: .init(x:dx, y:dy, width:dotW*c, height:dotH*c), cornerRadius:1*c), with:.color(lDots))
                }
                // 오른쪽 점선 (4점)
                for d in 0..<4 {
                    let dx = (33 + CGFloat(d) * dotGap) * c
                    ctx.fill(Path(roundedRect: .init(x:dx, y:dy, width:dotW*c, height:dotH*c), cornerRadius:1*c), with:.color(rDotColors[i]))
                }
            }
        }
        .frame(width: 64*sc, height: 72*sc)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - 2. 파일 아이콘 (파랑)
struct FileTabIcon: View {
    var isSelected: Bool
    var iconSize: CGFloat = 22
    private var sc: CGFloat { iconSize / 72 }

    var folderBack:  Color { isSelected ? Color(hex:"#1565C0") : Color(hex:"#AAAAAA") }
    var folderTab:   Color { isSelected ? Color(hex:"#1976D2") : Color(hex:"#BBBBBB") }
    var folderFront: Color { isSelected ? Color(hex:"#2196F3") : Color(hex:"#D0D0D0") }
    var folderFold:  Color { isSelected ? Color(hex:"#1976D2") : Color(hex:"#C0C0C0") }
    var paperColor:  Color { isSelected ? Color(hex:"#E3F2FD") : Color(hex:"#F0F0F0") }
    var dogEar:      Color { isSelected ? Color(hex:"#90CAF9") : Color(hex:"#E0E0E0") }

    var body: some View {
        Canvas { ctx, _ in
            let c = sc

            // 클립: y=4~72 로 상단 여백 줄여서 전체 높이 활용
            var clip = Path()
            clip.move(to:    .init(x:2*c,  y:10*c))
            clip.addQuadCurve(to: .init(x:6*c,  y:6*c),  control: .init(x:2*c,  y:6*c))
            clip.addLine(to: .init(x:26*c, y:6*c))
            clip.addQuadCurve(to: .init(x:29*c, y:8*c),  control: .init(x:28*c, y:6*c))
            clip.addLine(to: .init(x:32*c, y:12*c))
            clip.addLine(to: .init(x:58*c, y:12*c))
            clip.addQuadCurve(to: .init(x:62*c, y:16*c), control: .init(x:62*c, y:12*c))
            clip.addLine(to: .init(x:62*c, y:68*c))
            clip.addQuadCurve(to: .init(x:58*c, y:72*c), control: .init(x:62*c, y:72*c))
            clip.addLine(to: .init(x:6*c,  y:72*c))
            clip.addQuadCurve(to: .init(x:2*c,  y:68*c), control: .init(x:2*c,  y:72*c))
            clip.closeSubpath()
            ctx.clip(to: clip)

            ctx.fill(Path(.init(x:2*c,  y:6*c,  width:60*c, height:66*c)), with:.color(folderBack))

            var tab = Path()
            tab.move(to:    .init(x:2*c,  y:10*c))
            tab.addQuadCurve(to: .init(x:6*c,  y:6*c),  control: .init(x:2*c,  y:6*c))
            tab.addLine(to: .init(x:26*c, y:6*c))
            tab.addQuadCurve(to: .init(x:29*c, y:8*c),  control: .init(x:28*c, y:6*c))
            tab.addLine(to: .init(x:32*c, y:12*c))
            tab.addLine(to: .init(x:2*c,  y:12*c))
            tab.closeSubpath()
            ctx.fill(tab, with:.color(folderTab))

            ctx.fill(Path(.init(x:2*c, y:16*c, width:60*c, height:56*c)), with:.color(folderFront))
            ctx.fill(Path(.init(x:2*c, y:16*c, width:60*c, height:3*c)),  with:.color(folderFold))
            ctx.fill(Path(roundedRect: .init(x:12*c, y:24*c, width:40*c, height:40*c), cornerRadius:3*c), with:.color(paperColor))

            var d1 = Path()
            d1.move(to: .init(x:42*c, y:24*c))
            d1.addLine(to: .init(x:52*c, y:34*c))
            d1.addLine(to: .init(x:42*c, y:34*c))
            d1.closeSubpath()
            ctx.fill(d1, with:.color(dogEar))
        }
        .frame(width: 64*sc, height: 72*sc)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - 3. 메모 아이콘 (파스텔 그린)
struct MemoTabIcon: View {
    var isSelected: Bool
    var iconSize: CGFloat = 22
    private var sc: CGFloat { iconSize / 72 }

    var paperBg:    Color { isSelected ? Color(hex:"#C8EBD4") : Color(hex:"#EFEFEF") }
    var foldShadow: Color { isSelected ? Color(hex:"#8FC49F") : Color(hex:"#C8C8C8") }
    var foldFace:   Color { isSelected ? Color(hex:"#A8D5B5") : Color(hex:"#D8D8D8") }
    var ringBar:    Color { isSelected ? Color(hex:"#B8E0C4") : Color(hex:"#D5D5D5") }
    var ringHole:   Color { isSelected ? Color(hex:"#8FC49F") : Color(hex:"#C8C8C8") }
    var lineColors: [Color] { isSelected
        ? [Color(hex:"#6BAE82"), Color(hex:"#5BA070"), Color(hex:"#6BAE82"), Color(hex:"#5BA070")]
        : Array(repeating: Color(hex:"#D0D0D0"), count: 4) }

    let lineYs: [CGFloat] = [20, 30, 40, 50]
    let lineWs: [CGFloat] = [40, 32, 40, 24]

    var body: some View {
        Canvas { ctx, _ in
            let c  = sc
            let W  = 60 * c
            let H  = 72 * c
            let cr = 4  * c
            let fx = 44 * c
            let fy = 58 * c

            var clip = Path()
            clip.move(to:    .init(x:cr,   y:0))
            clip.addLine(to: .init(x:W-cr, y:0))
            clip.addQuadCurve(to: .init(x:W, y:cr),   control: .init(x:W, y:0))
            clip.addLine(to: .init(x:W,  y:fy))
            clip.addLine(to: .init(x:fx, y:H))
            clip.addLine(to: .init(x:cr, y:H))
            clip.addQuadCurve(to: .init(x:0, y:H-cr), control: .init(x:0, y:H))
            clip.addLine(to: .init(x:0, y:cr))
            clip.addQuadCurve(to: .init(x:cr, y:0),   control: .init(x:0, y:0))
            clip.closeSubpath()
            ctx.clip(to: clip)

            ctx.fill(Path(.init(x:0, y:0, width:W, height:H)), with:.color(paperBg))

            var sh = Path()
            sh.move(to: .init(x:fx,      y:H))
            sh.addLine(to: .init(x:W,    y:fy))
            sh.addLine(to: .init(x:W,    y:fy+2*c))
            sh.addLine(to: .init(x:fx+2*c, y:H))
            sh.closeSubpath()
            ctx.fill(sh, with:.color(foldShadow))

            var fold = Path()
            fold.move(to: .init(x:fx, y:fy))
            fold.addLine(to: .init(x:W,  y:fy))
            fold.addLine(to: .init(x:fx, y:H))
            fold.closeSubpath()
            ctx.fill(fold, with:.color(foldFace))

            ctx.fill(Path(.init(x:0, y:5*c, width:W, height:4*c)), with:.color(ringBar))

            for x: CGFloat in [14, 30, 46] {
                ctx.fill(Path(ellipseIn: .init(x:(x-3.5)*c, y:3.5*c, width:7*c, height:7*c)), with:.color(ringHole))
            }
            for i in 0..<4 {
                ctx.fill(Path(roundedRect: .init(x:8*c, y:lineYs[i]*c, width:lineWs[i]*c, height:3*c), cornerRadius:1.5*c), with:.color(lineColors[i]))
            }
        }
        .frame(width: 60*sc, height: 72*sc)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - 4. GM 아이콘 (퍼플 + 골드 별)
struct GMTabIcon: View {
    var isSelected: Bool
    var iconSize: CGFloat = 22
    private var sc: CGFloat { iconSize / 72 }

    var spineDark:  Color { isSelected ? Color(hex:"#5C3D8F") : Color(hex:"#AAAAAA") }
    var spineMain:  Color { isSelected ? Color(hex:"#7B52AB") : Color(hex:"#C0C0C0") }
    var cover:      Color { isSelected ? Color(hex:"#9B72CF") : Color(hex:"#D0D0D0") }
    var coverEdge:  Color { isSelected ? Color(hex:"#8860BC") : Color(hex:"#C8C8C8") }
    var page:       Color { isSelected ? Color(hex:"#F0EAFF") : Color(hex:"#F4F4F4") }
    var termColor:  Color { isSelected ? Color(hex:"#7B52AB") : Color(hex:"#D0D0D0") }
    var starColors: [Color] { isSelected
        ? [Color(hex:"#1565C0"), Color(hex:"#0288D1"), Color(hex:"#0097A7")]
        : [Color(hex:"#CCCCCC"), Color(hex:"#D4D4D4"), Color(hex:"#C8C8C8")] }

    // 줄 3개 (왼쪽만, 별 자리 확보)
    let rows: [(y: CGFloat, w: CGFloat)] = [
        (22, 22), (37, 18), (52, 20)
    ]
    // 별: 큰 별 하나 + 작은 별 둘 (우측 상단에 배치)
    let stars: [(cx: CGFloat, cy: CGFloat, r: CGFloat)] = [
        (48, 26, 10),   // 메인 큰 별
        (56, 44, 6),    // 중간 별
        (42, 55, 5),    // 작은 별
    ]

    var body: some View {
        Canvas { ctx, _ in
            let c  = sc
            let H  = 72 * c
            let cr = 6  * c

            var clip = Path()
            clip.move(to:    .init(x:2*c+cr,  y:0))
            clip.addLine(to: .init(x:64*c-cr, y:0))
            clip.addQuadCurve(to: .init(x:64*c, y:cr),   control: .init(x:64*c, y:0))
            clip.addLine(to: .init(x:64*c,    y:H-cr))
            clip.addQuadCurve(to: .init(x:64*c-cr, y:H), control: .init(x:64*c, y:H))
            clip.addLine(to: .init(x:2*c+cr,  y:H))
            clip.addQuadCurve(to: .init(x:2*c, y:H-cr),  control: .init(x:2*c, y:H))
            clip.addLine(to: .init(x:2*c,     y:cr))
            clip.addQuadCurve(to: .init(x:2*c+cr, y:0),  control: .init(x:2*c, y:0))
            clip.closeSubpath()
            ctx.clip(to: clip)

            // 척추 · 표지
            ctx.fill(Path(.init(x:2*c, y:0, width:4*c,  height:H)), with:.color(spineDark))
            ctx.fill(Path(.init(x:2*c, y:0, width:5*c,  height:H)), with:.color(spineMain))
            ctx.fill(Path(.init(x:7*c, y:0, width:57*c, height:H)), with:.color(cover))
            ctx.fill(Path(.init(x:7*c, y:0, width:2*c,  height:H)), with:.color(coverEdge))
            // 내지
            ctx.fill(Path(roundedRect: .init(x:10*c, y:8*c, width:47*c, height:56*c), cornerRadius:3*c), with:.color(page))

            // 텍스트 줄 (왼쪽 절반만)
            for row in rows {
                ctx.fill(Path(roundedRect: .init(x:13*c, y:row.y*c, width:row.w*c, height:3*c), cornerRadius:1.5*c), with:.color(termColor))
            }

            // 별 3개 — 크고 선명하게
            for (i, s) in stars.enumerated() {
                ctx.fill(starPath(cx:s.cx*c, cy:s.cy*c, r:s.r*c), with:.color(starColors[i]))
            }
        }
        .frame(width: 64*sc, height: 72*sc)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    private func starPath(cx: CGFloat, cy: CGFloat, r: CGFloat) -> Path {
        var p = Path()
        let inner = r * 0.38
        for i in 0..<10 {
            let angle = (CGFloat(i) * .pi / 5) - .pi / 2
            let radius = i.isMultiple(of: 2) ? r : inner
            let pt = CGPoint(x: cx + radius * cos(angle), y: cy + radius * sin(angle))
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }
}
