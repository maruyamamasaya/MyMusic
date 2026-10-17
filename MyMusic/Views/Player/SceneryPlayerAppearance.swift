import SwiftUI

enum SceneryPlayerAppearance {
    static let display = Color(red: 0.73, green: 0.91, blue: 0.96)
}

struct ScenerySmokedPanel: View {
    let opaque: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(LinearGradient(colors: [Color(red: 0.16, green: 0.19, blue: 0.21).opacity(opaque ? 1 : 0.95),
                                          Color(red: 0.025, green: 0.045, blue: 0.055).opacity(opaque ? 1 : 0.9),
                                          Color(red: 0.065, green: 0.085, blue: 0.10).opacity(opaque ? 1 : 0.94)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(LinearGradient(stops: [.init(color: .white.opacity(0.85), location: 0),
                                                         .init(color: Color(white: 0.48), location: 0.18),
                                                         .init(color: Color(white: 0.15), location: 0.48),
                                                         .init(color: .white.opacity(0.55), location: 0.78),
                                                         .init(color: Color(white: 0.28), location: 1)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.3)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8.5).inset(by: 1.6)
                    .strokeBorder(.black.opacity(0.8), lineWidth: 0.8)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8).inset(by: 2.5)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.18), .clear, .white.opacity(0.05)],
                                                 startPoint: .top, endPoint: .bottom), lineWidth: 0.5)
            }
    }
}

/// A static sheet of faint reflected light over the display, not a live blur or a hit target.
struct SceneryGlassReflection: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                LinearGradient(stops: [.init(color: .white.opacity(0.13), location: 0),
                                       .init(color: .white.opacity(0.025), location: 0.32),
                                       .init(color: .clear, location: 0.55)], startPoint: .top, endPoint: .bottom)
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    path.move(to: CGPoint(x: width * 0.24, y: 0))
                    path.addLine(to: CGPoint(x: width * 0.45, y: 0))
                    path.addLine(to: CGPoint(x: width * 0.30, y: height))
                    path.addLine(to: CGPoint(x: width * 0.13, y: height))
                    path.closeSubpath()
                }
                .fill(LinearGradient(colors: [.white.opacity(0.04), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct SceneryMetalPlaybackStyle: ButtonStyle {
    var diameter: CGFloat = 32

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(LinearGradient(colors: [.white, SceneryPlayerAppearance.display.opacity(0.85)],
                                            startPoint: .top, endPoint: .bottom))
            .shadow(color: .black.opacity(0.8), radius: 0.4, y: 0.7)
            .background {
                Circle()
                    .fill(LinearGradient(stops: [.init(color: Color(white: 0.82), location: 0),
                                                 .init(color: Color(white: 0.23), location: 0.22),
                                                 .init(color: Color(white: 0.08), location: 0.53),
                                                 .init(color: Color(white: 0.62), location: 0.82),
                                                 .init(color: Color(white: 0.24), location: 1)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay {
                        Circle().inset(by: 2)
                            .fill(RadialGradient(colors: [Color(white: 0.56), Color(white: 0.35), Color(white: 0.17)],
                                                 center: .init(x: 0.3, y: 0.2), startRadius: 0, endRadius: 30))
                    }
                    .overlay {
                        Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.95), .black.opacity(0.9), .white.opacity(0.65)],
                                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.7)
                    }
                    .overlay {
                        Circle().inset(by: 2).strokeBorder(LinearGradient(colors: [.white.opacity(0.8), .black.opacity(0.7)],
                                                                         startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.7)
                    }
                    .overlay {
                        Ellipse().fill(LinearGradient(colors: [.white.opacity(0.38), .clear], startPoint: .top, endPoint: .bottom))
                            .frame(width: 19, height: 10).rotationEffect(.degrees(-25)).offset(x: -3, y: -7)
                    }
                    .frame(width: diameter, height: diameter)
                    .shadow(color: .black.opacity(0.75), radius: 1.5, y: 1.5)
            }
            .offset(y: configuration.isPressed ? 0.5 : 0)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct SceneryDotRecord: View {
    var body: some View {
        Canvas { context, size in
            let step = min(size.width, size.height) / 17
            var dots = Path()
            for row in 0..<17 {
                for column in 0..<17 {
                    let x = Double(column - 8) / 8
                    let y = Double(row - 8) / 8
                    let radius = (x * x + y * y).squareRoot()
                    if (0.87...1.0).contains(radius) || (0.62...0.72).contains(radius)
                        || (0.38...0.48).contains(radius) || radius < 0.13 {
                        dots.addRect(CGRect(x: CGFloat(column) * step, y: CGFloat(row) * step,
                                            width: step * 0.72, height: step * 0.72))
                    }
                }
            }
            context.fill(dots, with: .color(SceneryPlayerAppearance.display.opacity(0.9)))
        }
        .scaleEffect(x: 1, y: 0.62)
        .rotationEffect(.degrees(-24))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
