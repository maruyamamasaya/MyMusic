import SwiftUI

/// Lightweight sphere / Blue Cosmos night-sky fallback when Metal is unavailable.
struct VisualWorldScene: View {
    let theme: AppTheme
    let primary: Color
    let secondary: Color
    let motion: VisualWorldDynamics
    var energy = 0.5
    var ambient = 0.5
    var brightness = 0.5
    var subdued = false

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            if theme == .blueCosmos {
                nightSky(context: &context, size: size)
                return
            }
            if theme == .pulseNeon {
                lightGates(context: &context, size: size)
                return
            }
            let radius = min(size.width, size.height) * 0.45
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.43)
            let sphere = Path(ellipseIn: CGRect(x: center.x-radius, y: center.y-radius, width: radius*2, height: radius*2))
            let highlight = CGPoint(x: center.x-radius*0.35, y: center.y-radius*0.4)
            context.opacity = subdued ? 0.4 : 1
            for side in 0..<2 {
                let source = CGPoint(x: center.x + radius * (side == 0 ? -0.35 : 0.35), y: center.y)
                context.fill(Path(ellipseIn: CGRect(x: source.x-radius*1.7, y: source.y-radius*1.7,
                                                    width: radius*3.4, height: radius*3.4)),
                             with: .radialGradient(Gradient(colors: [(side == 0 ? primary : secondary).opacity(0.3), .clear]),
                                                   center: source, startRadius: radius*0.5, endRadius: radius*1.7))
            }
            context.fill(sphere, with: .radialGradient(Gradient(colors: [primary.opacity(0.8), secondary.opacity(0.35), .black]),
                                                      center: highlight, startRadius: 0, endRadius: radius*1.7))
            context.clip(to: sphere)
            context.blendMode = .plusLighter
            for index in 0..<160 {
                let seed = Double(index) * 2.399963
                let z = 1 - 2 * (Double(index)+0.5)/160
                let radial = sqrt(max(0,1-z*z))
                let angle = seed + motion.time * 0.3
                let x = radial*cos(angle), depth = radial*sin(angle)
                let point = CGPoint(x: center.x+x*radius*0.94, y: center.y+z*radius*0.94)
                let dotRadius = 0.5 + (depth+1)*0.65
                let alpha = (0.12+(depth+1)*0.25) * (0.6+motion.level*0.4)
                let dot = Path(ellipseIn: CGRect(x: point.x-dotRadius, y: point.y-dotRadius,
                                                width: dotRadius*2, height: dotRadius*2))
                context.fill(dot, with: .color((index%4 == 0 ? .white : primary).opacity(alpha)))
            }
        }
        .accessibilityHidden(true)
    }

    private func lightGates(context: inout GraphicsContext, size: CGSize) {
        context.opacity = subdued ? 0.4 : 1
        context.blendMode = .plusLighter
        let unit = min(size.width,size.height)*0.5
        let center = CGPoint(x: size.width*0.5, y: size.height*0.43)
        for index in 0..<8 {
            let phase = (Double(index)+0.5)/8-motion.time*0.32
            let depth = phase-floor(phase)
            let scale = unit/(0.3+depth*9)
            let opacity = min(depth/0.07,1)*min((1-depth)/0.16,1)
            func point(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(x: center.x+x*scale,y: center.y-y*scale)
            }
            var path = Path()
            for side in [-1.0,1.0] {
                path.move(to: point(side*0.85,-1.1)); path.addLine(to: point(side*1.4,1.1))
                path.move(to: point(side*1.4,-1.1)); path.addLine(to: point(side*0.85,1.1))
            }
            for y in [-1.1,1.1] {
                path.move(to: point(-1.4,y)); path.addLine(to: point(1.4,y))
            }
            let gradient = GraphicsContext.Shading.linearGradient(Gradient(colors: [primary,secondary]),
                startPoint: point(-1.4,1.1),endPoint: point(1.4,-1.1))
            var layer = context
            layer.opacity *= opacity
            layer.stroke(path,with: gradient,lineWidth: max(2,scale*0.055))
            layer.stroke(path,with: .color(.white.opacity(0.8)),lineWidth: max(0.7,scale*0.008))
        }
    }

    private func nightSky(context: inout GraphicsContext, size: CGSize) {
        let blue = Color(red: 0.15, green: 0.36, blue: 0.9)
        context.opacity = subdued ? 0.4 : 1
        let center = CGPoint(x: size.width*0.45, y: size.height*0.43)
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .radialGradient(Gradient(colors: [primary.opacity(0.1), blue.opacity(0.08), .black]),
                                           center: center, startRadius: 0, endRadius: size.height*0.6))
        func random(_ value: Double) -> Double {
            let n = sin(value*127.1+311.7)*43758.5453
            return n-floor(n)
        }
        context.blendMode = .plusLighter
        for i in 0..<200 {
            let seed = random(Double(i))
            let depth = random(Double(i)+227)
            let driftPhase = random(Double(i)+239)*2*Double.pi
            let rate = (0.18+random(Double(i)+251)*0.12)*(1+depth*0.36)
            let driftRadius = 0.002+depth*0.006
            let driftX = sin(motion.time*rate+driftPhase)*driftRadius
            let driftY = cos(motion.time*rate*0.73+driftPhase*1.7)*driftRadius
            let x = (random(Double(i)+41) + motion.time*0.0008 + driftX + 1).truncatingRemainder(dividingBy: 1)
            let y = random(Double(i)+97) + driftY
            let sizeSeed = random(Double(i)+53)
            let sizeMix = min(max((sizeSeed-0.82)/0.18,0),1)
            let largerStar = sizeMix*sizeMix*(3-2*sizeMix)
            let radius = 0.3 + sizeSeed*0.42 + largerStar*0.75
            let center = CGPoint(x: x*size.width, y: y*size.height)
            let behavior = random(Double(i)+83)
            let phaseValue = (motion.time*2.4)/(1.2+random(Double(i)+151)*2.2)+random(Double(i)+173)
            let phase = phaseValue-floor(phaseValue)
            func smooth(_ low: Double, _ high: Double, _ value: Double) -> Double {
                let x = min(max((value-low)/(high-low),0),1)
                return x*x*(3-2*x)
            }
            let pulse = smooth(0,0.1,phase)*(1-smooth(0.1,0.42,phase))
            var light = 0.85
            if behavior >= 0.45 && behavior < 0.8 {
                light = (0.08+1.5*pow(0.5+0.5*sin(motion.time*(1.8+seed*2)+seed*71),2))*(0.8+motion.level*0.5)
            } else if behavior >= 0.8 {
                light = 0.06+pulse*(2.6+motion.level*1.5)
            }
            let alpha = min((0.35+seed*0.45)*light,1)
            let colorSeed = random(Double(i)+109)
            let artwork = colorSeed < 0.6 ? primary : secondary
            let temperature = colorSeed < 0.55 ? blue : Color(red: 1,green: 0.3,blue: 0.2)
            let dot = Path(ellipseIn: CGRect(x: center.x-radius,y: center.y-radius,width: radius*2,height: radius*2))
            context.fill(dot,with: .color(artwork.opacity(alpha*0.8)))
            context.fill(dot,with: .color(temperature.opacity(alpha*0.3)))
            if behavior >= 0.8 { context.fill(dot,with: .color(.white.opacity(alpha*pulse*0.35))) }
            if behavior >= 0.8 {
                context.fill(Path(ellipseIn: CGRect(x: center.x-3,y: center.y-3,width: 6,height: 6)),
                             with: .radialGradient(Gradient(colors: [artwork.opacity(alpha*pulse*0.45), .clear]),
                                                   center: center,startRadius: 0,endRadius: 3))
            }
        }
    }

}
