import SwiftUI

// Copied from voice-recorder-ios Sources/UI/Widgets.swift (the record widget's microphone).

/// Minimal Android pathData parser (M L H V C S Z, absolute and relative).
enum VectorPath {
    static func parse(_ d: String) -> Path {
        var tokens: [String] = []
        var num = ""
        func flush() { if !num.isEmpty { tokens.append(num); num = "" } }
        for ch in d {
            if ch.isLetter && ch != "e" {
                flush(); tokens.append(String(ch))
            } else if ch == "-" && !num.isEmpty && !num.hasSuffix("e") {
                flush(); num = "-"
            } else if ch == "." && num.contains(".") {
                flush(); num = "."
            } else if ch == " " || ch == "," {
                flush()
            } else {
                num.append(ch)
            }
        }
        flush()

        var p = Path()
        var i = 0
        var cmd: Character = "M"
        var cur = CGPoint.zero, start = CGPoint.zero, lastCtrl: CGPoint?
        func n() -> CGFloat { defer { i += 1 }; return CGFloat(Double(tokens[i]) ?? 0) }
        while i < tokens.count {
            if let c = tokens[i].first, c.isLetter { cmd = c; i += 1 }
            let rel = cmd.isLowercase
            let o = rel ? cur : .zero
            switch cmd.uppercased() {
            case "M":
                cur = CGPoint(x: o.x + n(), y: o.y + n()); start = cur; p.move(to: cur); lastCtrl = nil
                cmd = rel ? "l" : "L"
            case "L":
                cur = CGPoint(x: o.x + n(), y: o.y + n()); p.addLine(to: cur); lastCtrl = nil
            case "H":
                cur.x = (rel ? cur.x : 0) + n(); p.addLine(to: cur); lastCtrl = nil
            case "V":
                cur.y = (rel ? cur.y : 0) + n(); p.addLine(to: cur); lastCtrl = nil
            case "C":
                let c1 = CGPoint(x: o.x + n(), y: o.y + n()), c2 = CGPoint(x: o.x + n(), y: o.y + n())
                cur = CGPoint(x: o.x + n(), y: o.y + n())
                p.addCurve(to: cur, control1: c1, control2: c2); lastCtrl = c2
            case "S":
                let c1 = lastCtrl.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
                let c2 = CGPoint(x: o.x + n(), y: o.y + n())
                cur = CGPoint(x: o.x + n(), y: o.y + n())
                p.addCurve(to: cur, control1: c1, control2: c2); lastCtrl = c2
            case "Z":
                p.closeSubpath(); cur = start; lastCtrl = nil
                continue
            default:
                i += 1
            }
        }
        return p
    }
}
