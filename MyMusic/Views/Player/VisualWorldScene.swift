import SwiftUI

/// Lightweight Canvas fallback when Metal is unavailable.
struct VisualWorldScene: View {
    let style: VisualWorldStyle
    let primary: Color
    let secondary: Color
    let motion: VisualWorldDynamics
    var worldSeed = 0.0
    var energy = 0.5
    var ambient = 0.5
    var brightness = 0.5
    var aggressive = 0.5
    var electronic = 0.5
    var bands = [Float](repeating: 0, count: 24)
    var waveform = [Float](repeating: 0, count: 48)
    var bass = 0.0
    var mid = 0.0
    var treble = 0.0
    var beat = 0.0
    var subdued = false

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            if style == .nightSky {
                nightSky(context: &context, size: size)
                return
            }
            if style == .lightGates {
                lightGates(context: &context, size: size)
                return
            }
            if style == .twilight {
                twilight(context: &context, size: size)
                return
            }
            if style == .plasmaSpark {
                plasmaSpark(context: &context, size: size)
                return
            }
            if style == .visualizer {
                visualizer(context: &context, size: size)
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
            var sphereContext = context
            sphereContext.clip(to: sphere)
            sphereContext.blendMode = .plusLighter
            for index in 0..<160 {
                let seed = Double(index) * 2.399963
                let z = 1 - 2 * (Double(index)+0.5)/160
                let radial = sqrt(max(0,1-z*z))
                let angle = seed + motion.time * 0.3
                let x = radial*cos(angle), depth = radial*sin(angle)
                let point = CGPoint(x: center.x+x*radius*0.94, y: center.y+z*radius*0.94)
                let dotRadius = 0.5 + (depth+1)*0.65
                let alpha = (0.12+(depth+1)*0.25) * (0.42+motion.level*0.95)
                let dot = Path(ellipseIn: CGRect(x: point.x-dotRadius, y: point.y-dotRadius,
                                                width: dotRadius*2, height: dotRadius*2))
                sphereContext.fill(dot, with: .color((index%4 == 0 ? .white : primary).opacity(alpha)))
            }
            sphereSatellites(context: &context, size: size)
        }
        .accessibilityHidden(true)
    }

    private func sphereSatellites(context: inout GraphicsContext, size: CGSize) {
        let unit = min(size.width, size.height) * 0.5
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.43)
        func seed(_ i: Int, _ offset: Double) -> Double {
            let value = sin((Double(i) + offset + worldSeed) * 127.1 + 311.7) * 43758.5453
            return value - floor(value)
        }
        context.blendMode = .plusLighter
        for i in 0..<16 {
            let value = seed(i, 3)
            let time = motion.time
            let phase = value*2*Double.pi + time*(0.26+seed(i, 51)*0.26)*(i % 3 == 0 ? -1 : 1)
                + sin(time*(0.16+value*0.12)+value*21)*0.24
                + sin(time*(0.38+value*0.2)+value*33)*0.08
            let point = CGPoint(x: center.x + unit*(cos(phase)*(0.84+value*0.1)
                + sin(time*(0.43+value*0.23)+value*17)*0.035),
                                y: center.y + unit*(sin(phase)*(0.98+value*0.14)
                + cos(time*(0.29+value*0.18)+value*39)*0.06))
            let radius = unit*(0.0025+seed(i, 87)*0.0032)
            let shimmer = 0.25+0.75*pow(0.5+0.5*sin(time*(1.2+value*4)+value*41),3)
            let color = i.isMultiple(of: 2) ? primary : secondary
            let dot = Path(ellipseIn: CGRect(x: point.x-radius, y: point.y-radius,
                                            width: radius*2, height: radius*2))
            context.fill(dot, with: .color(color.opacity(min(1,shimmer*(0.7+motion.level*0.4)))))
            context.fill(dot, with: .color(.white.opacity(min(1,shimmer*(0.25+motion.level*0.3)))))
        }
        for i in 0..<3 {
            let value = seed(i, 113)
            let time = motion.time
            let phase = value*2*Double.pi + time*(0.25+value*0.2)*(i == 1 ? -1 : 1)
                + sin(time*(0.18+value*0.14)+value*12)*0.3
                + sin(time*(0.42+value*0.17)+value*26)*0.1
            let point = CGPoint(x: center.x + unit*(cos(phase)*(0.82+value*0.12)
                + sin(time*(0.33+value*0.2)+value*18)*0.04),
                                y: center.y + unit*(sin(phase)*(1+value*0.12)
                + cos(time*(0.27+value*0.16)+value*27)*0.065))
            let radius = unit*(0.011+value*0.006)
            let sphere = Path(ellipseIn: CGRect(x: point.x-radius, y: point.y-radius,
                                               width: radius*2, height: radius*2))
            let color = i == 1 ? secondary : primary
            context.fill(sphere, with: .radialGradient(
                Gradient(colors: [.white.opacity(0.88), color.opacity(0.85), color.opacity(0.18)]),
                center: CGPoint(x: point.x-radius*0.32, y: point.y-radius*0.36),
                startRadius: 0, endRadius: radius*1.6))
        }
    }

    private func visualizer(context: inout GraphicsContext, size: CGSize) {
        context.opacity = subdued ? 0.4 : 1
        let cyan = primary
        let violet = secondary
        let accent = Color(red: 1, green: 0.34, blue: 0.57)
        let background = Path(CGRect(origin: .zero, size: size))
        context.fill(background, with: .radialGradient(
            Gradient(colors: [cyan.opacity(0.035+ambient*0.025+beat*0.025), .black]),
            center: CGPoint(x: size.width*0.5,y: size.height*0.52),
            startRadius: 0, endRadius: size.height*0.6))
        context.blendMode = .plusLighter

        // PCM waveform: the quiet rear layer stays readable behind the EQ bars.
        if waveform.count >= 48 {
            var trace = Path()
            var echo = Path()
            for i in 0..<48 {
                let x = size.width*(0.06+Double(i)/47*0.88)
                let sample = min(1,max(-1,Double(waveform[i])))
                let amplitude = size.height*(0.065+ambient*0.045+beat*0.018)
                let point = CGPoint(x: x,y: size.height*0.40+sample*amplitude)
                let reflected = CGPoint(x: x,y: size.height*0.43-sample*amplitude*0.55)
                if i == 0 {
                    trace.move(to: point)
                    echo.move(to: reflected)
                } else {
                    trace.addLine(to: point)
                    echo.addLine(to: reflected)
                }
            }
            let tint = GraphicsContext.Shading.linearGradient(
                Gradient(colors: [cyan.opacity(0.4),violet.opacity(0.5)]),
                startPoint: CGPoint(x: 0,y: size.height*0.4),
                endPoint: CGPoint(x: size.width,y: size.height*0.4))
            context.stroke(trace, with: tint, lineWidth: 1.6)
            context.stroke(trace, with: .color(cyan.opacity(0.08+ambient*0.06)), lineWidth: 7)
            context.stroke(echo, with: .color(violet.opacity(0.06+ambient*0.05)), lineWidth: 1)
        }

        let baseline = size.height*0.69
        let width = size.width*0.84/24
        for index in 0..<24 {
            let response = index < bands.count ? min(1,max(0,Double(bands[index]))) : 0
            let frequency = (Double(index)+0.5)/24
            let range = frequency < 0.33 ? bass : frequency < 0.7 ? mid : treble
            let height = size.height*(0.014+pow(min(1,response+range*0.12),0.82)*(0.22+energy*0.13))
            let x = size.width*0.08+(Double(index)+0.5)*width
            let barWidth = width*(0.38+electronic*0.12)
            let rect = CGRect(x: x-barWidth/2,y: baseline-height,width: barWidth,height: height)
            let hue = frequency < 0.5 ? cyan : frequency < 0.76 ? violet : accent
            let intensity = 0.5+brightness*0.4+beat*0.25
            context.fill(Path(roundedRect: rect.insetBy(dx: -2,dy: -2),cornerRadius: 3),
                         with: .color(hue.opacity(0.035*intensity)))
            context.fill(Path(roundedRect: rect,cornerRadius: min(3,barWidth*0.2)),
                         with: .linearGradient(
                            Gradient(colors: [hue.opacity(0.95*intensity),
                                              hue.opacity(0.34*intensity)]),
                            startPoint: CGPoint(x: x,y: rect.minY),
                            endPoint: CGPoint(x: x,y: rect.maxY)))
            let cap = Path(ellipseIn: CGRect(x: x-barWidth*0.44,y: rect.minY-1.5,
                                             width: barWidth*0.88,height: 3))
            context.fill(cap, with: .color(.white.opacity(min(1,0.3+aggressive*0.2+beat*0.3))))
        }
        var baselinePath = Path()
        baselinePath.move(to: CGPoint(x: size.width*0.08,y: baseline))
        baselinePath.addLine(to: CGPoint(x: size.width*0.92,y: baseline))
        context.stroke(baselinePath, with: .color(cyan.opacity(0.06+beat*0.12)),lineWidth: 1)

        func random(_ value: Double) -> Double {
            let raw = sin((value+worldSeed)*127.1+311.7)*43758.5453
            return raw-floor(raw)
        }
        for index in 0..<72 {
            let seed = random(Double(index)+7)
            let drift = motion.time*(0.2+ambient*0.18)
            let x = (random(Double(index)+19)+drift*0.04).truncatingRemainder(dividingBy: 1)*size.width
            let y = (random(Double(index)+37)-drift*(0.04+seed*0.02)+100)
                .truncatingRemainder(dividingBy: 1)*size.height
            let radius = 0.5+seed*1.2
            let pulse = 0.35+0.65*pow(0.5+0.5*sin(motion.time*(1.2+seed)+seed*37),2)
            let particle = Path(ellipseIn: CGRect(x: x-radius,y: y-radius,
                                                  width: radius*2,height: radius*2))
            let tint = index.isMultiple(of: 3) ? accent : (index.isMultiple(of: 2) ? cyan : violet)
            context.fill(particle, with: .color(tint.opacity(
                min(1,pulse*(0.28+ambient*0.18+treble*0.2+beat*(0.25+aggressive*0.2))))))
        }
    }

    private func plasmaSpark(context: inout GraphicsContext, size: CGSize) {
        context.opacity = subdued ? 0.4 : 1
        let unit = size.height
        let time = motion.time * 6
        let activity = min(1, motion.level)
        let violet = Color(red: 0.43, green: 0.12, blue: 0.94)
        let cyan = Color(red: 0.08, green: 0.74, blue: 1)
        let rose = Color(red: 1, green: 0.13, blue: 0.55)
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        let background = Path(CGRect(origin: .zero, size: size))
        context.fill(background, with: .radialGradient(
            Gradient(colors: [primary.opacity(0.10), .black]),
            center: center, startRadius: 0, endRadius: unit * 0.65))
        context.blendMode = .plusLighter

        func position(_ current: Int, _ y: Double) -> CGPoint {
            let n = Double(current)
            let phase = time * (0.48+n*0.13)+n*2.1+worldSeed*0.7
            let base = (n-1)*0.18+sin(time*0.23+n*2.5)*0.13
            let bend = sin(y*8-phase)*0.09
                + sin(y*17+phase*1.43+n*3)*0.035
                + sin(y*32-phase*2.4+n)*0.012
            return CGPoint(x: center.x+(base+bend)*unit,
                           y: center.y+y*unit)
        }

        for current in 0..<3 {
            let hue = current == 0 ? violet : current == 1 ? cyan : rose
            var body = Path()
            var branch = Path()
            for step in 0...80 {
                let y = -0.53+Double(step)*1.06/80
                let point = position(current,y)
                if step == 0 { body.move(to: point) } else { body.addLine(to: point) }
                let n = Double(current)
                let window = pow(max(0,sin(y*5-time*(0.72+n*0.09)+n*2.2)),7)
                let branchX = sin(y*15+time*1.2+n*4)*unit*0.13*window
                let branchPoint = CGPoint(x: point.x+branchX,y: point.y)
                if step == 0 { branch.move(to: branchPoint) }
                else { branch.addLine(to: branchPoint) }
            }
            let intensity = 0.55+activity*0.35
            context.stroke(body, with: .color(hue.opacity(0.035*intensity)),
                           style: StrokeStyle(lineWidth: unit*0.24, lineCap: .round, lineJoin: .round))
            context.stroke(body, with: .color(hue.opacity(0.14*intensity)),
                           style: StrokeStyle(lineWidth: unit*0.07, lineCap: .round, lineJoin: .round))
            context.stroke(body, with: .color(hue.opacity(0.72*intensity)),
                           style: StrokeStyle(lineWidth: max(1,unit*0.005), lineCap: .round, lineJoin: .round))
            context.stroke(branch, with: .color(hue.opacity(0.32*intensity)),
                           style: StrokeStyle(lineWidth: max(1,unit*0.002), lineCap: .round))
            for packet in 0..<5 {
                let phase = Double(packet)/5+Double(current)*0.17-time*(0.075+Double(current)*0.014)
                let y = (phase-floor(phase))*1.06-0.53
                let point = position(current,y)
                let radius = unit*(0.008+activity*0.004)
                let glow = Path(ellipseIn: CGRect(x: point.x-radius*5,y: point.y-radius*5,
                                                  width: radius*10,height: radius*10))
                let core = Path(ellipseIn: CGRect(x: point.x-radius,y: point.y-radius,
                                                  width: radius*2,height: radius*2))
                context.fill(glow, with: .radialGradient(
                    Gradient(colors: [hue.opacity(0.4),.clear]), center: point,
                    startRadius: 0, endRadius: radius*5))
                context.fill(core, with: .color(.white.opacity(0.85)))
            }
        }
        func random(_ value: Double) -> Double {
            let raw = sin(value*127.1+worldSeed*31.3)*43758.5453
            return raw-floor(raw)
        }
        for index in 0..<100 {
            let seed = random(Double(index)+11)
            let life = time*(0.18+seed*0.1)+random(Double(index)+29)*8
            let phase = life-floor(life)
            let fade = sin(phase*Double.pi)
            let x = random(Double(index)+43)*size.width + (seed-0.5)*phase*unit*0.08
            let y = size.height*(1-(random(Double(index)+67)+phase*0.6)
                .truncatingRemainder(dividingBy: 1))
            let radius = 0.5+random(Double(index)+83)*1.3
            let dot = Path(ellipseIn: CGRect(x: x-radius,y: y-radius,
                                            width: radius*2,height: radius*2))
            let hue = index.isMultiple(of: 2) ? cyan : rose
            context.fill(dot, with: .color(hue.opacity(fade*(0.28+activity*0.45))))
        }
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
            let opacity = min(1, min(depth/0.07,1)*min((1-depth)/0.16,1)*(0.62+motion.level*0.75))
            let raw = sin((Double(index)+17)*127.1+floor(phase)*311.7+worldSeed*41)*43758.5453
            let shapeSeed = raw-floor(raw)
            let pattern = (Int(shapeSeed*5)+index)%5
            func point(_ x: Double, _ y: Double) -> CGPoint {
                CGPoint(x: center.x+x*scale,y: center.y-y*scale)
            }
            var path = Path()
            func segment(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) {
                path.move(to: point(x1,y1))
                path.addLine(to: point(x2,y2))
            }
            switch pattern {
            case 0:
                for side in [-1.0,1.0] {
                    segment(side*0.85,-1.1,side*1.4,1.1)
                    segment(side*1.4,-1.1,side*0.85,1.1)
                }
                segment(-1.4,1.1,1.4,1.1)
                segment(-1.4,-1.1,1.4,-1.1)
            case 1:
                segment(-1.5,0,0,1.3); segment(0,1.3,1.5,0)
                segment(1.5,0,0,-1.3); segment(0,-1.3,-1.5,0)
            case 2:
                segment(-0.8,1.15,0.8,1.15); segment(0.8,1.15,1.5,0)
                segment(1.5,0,0.8,-1.15); segment(0.8,-1.15,-0.8,-1.15)
                segment(-0.8,-1.15,-1.5,0); segment(-1.5,0,-0.8,1.15)
            case 3:
                segment(-1.5,1.15,0,0.48); segment(0,0.48,1.5,1.15)
                segment(-1.5,-1.15,0,-0.48); segment(0,-0.48,1.5,-1.15)
                segment(-1.5,-1.15,-1.5,1.15); segment(1.5,-1.15,1.5,1.15)
            default:
                segment(-1.5,-1.15,-1.5,0.55); segment(-1.5,0.55,-0.8,0.55)
                segment(-0.8,0.55,-0.8,1.15); segment(-0.8,1.15,1.5,1.15)
                segment(1.5,1.15,1.5,-0.55); segment(1.5,-0.55,0.8,-0.55)
                segment(0.8,-0.55,0.8,-1.15); segment(0.8,-1.15,-1.5,-1.15)
            }
            let gradient = GraphicsContext.Shading.linearGradient(Gradient(colors: [primary,secondary]),
                startPoint: point(-1.4,1.1),endPoint: point(1.4,-1.1))
            var layer = context
            layer.opacity *= opacity
            layer.stroke(path,with: gradient,lineWidth: max(2,scale*(0.05+motion.level*0.035)))
            layer.stroke(path,with: .color(.white.opacity(0.8)),lineWidth: max(0.7,scale*0.008))
        }
    }

    private func twilight(context: inout GraphicsContext, size: CGSize) {
        context.opacity = subdued ? 0.4 : 1
        let sky = Path(CGRect(origin: .zero, size: size))
        context.fill(sky, with: .linearGradient(
            Gradient(stops: [
                .init(color: Color(red: 0.008, green: 0.025, blue: 0.11), location: 0),
                .init(color: Color(red: 0.025, green: 0.08, blue: 0.22), location: 0.55),
                .init(color: Color(red: 0.065, green: 0.16, blue: 0.31), location: 0.75),
                .init(color: Color(red: 0.28, green: 0.15, blue: 0.3), location: 0.81),
                .init(color: Color(red: 0.43, green: 0.19, blue: 0.22), location: 0.87),
                .init(color: Color(red: 0.035, green: 0.035, blue: 0.12), location: 1)
            ]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))

        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.79)
        let glowRadius = min(size.width * 0.8, size.height * 0.22)
        let glow = Path(ellipseIn: CGRect(x: center.x-glowRadius, y: center.y-glowRadius*0.52,
                                         width: glowRadius*2, height: glowRadius*1.04))
        context.fill(glow, with: .radialGradient(
            Gradient(colors: [Color(red: 1, green: 0.66, blue: 0.34).opacity(0.12 + motion.level*0.22), .clear]),
            center: center, startRadius: 0, endRadius: glowRadius))
        context.fill(glow, with: .radialGradient(
            Gradient(colors: [secondary.opacity(0.05), primary.opacity(0.025), .clear]),
            center: center, startRadius: 0, endRadius: glowRadius))

        for layer in 0..<3 {
            let baseline = size.height * (0.52 + Double(layer) * 0.13)
            let drift = motion.time * (0.5 + energy*0.55 + Double(layer) * 0.45)
            let amplitude = size.height * (0.018 + Double(layer) * 0.008)
            var cloud = Path()
            cloud.move(to: CGPoint(x: 0, y: baseline))
            for step in 0...24 {
                let x = size.width * Double(step) / 24
                let wave = sin(x / size.width * 9 + drift) * 0.65
                    + sin(x / size.width * 19 - drift * 0.73) * 0.35
                cloud.addLine(to: CGPoint(x: x, y: baseline + wave * amplitude))
            }
            cloud.addLine(to: CGPoint(x: size.width, y: baseline + size.height * 0.065))
            cloud.addLine(to: CGPoint(x: 0, y: baseline + size.height * 0.065))
            cloud.closeSubpath()
            let cloudColor: Color = switch layer {
            case 0: Color(red: 0.045, green: 0.09, blue: 0.22)
            case 1: Color(red: 0.07, green: 0.12, blue: 0.27)
            default: Color(red: 0.075, green: 0.045, blue: 0.15)
            }
            context.fill(cloud, with: .linearGradient(
                Gradient(colors: [cloudColor.opacity(0.34 + Double(layer)*0.12 + motion.level*0.13), cloudColor.opacity(0.04)]),
                startPoint: CGPoint(x: 0, y: baseline),
                endPoint: CGPoint(x: 0, y: baseline + size.height*0.065)))
        }
        drawStars(context: &context, size: size, dim: 0.65, skyFraction: 0.84)
    }

    private func nightSky(context: inout GraphicsContext, size: CGSize) {
        let blue = Color(red: 0.15, green: 0.36, blue: 0.9)
        context.opacity = subdued ? 0.4 : 1
        let center = CGPoint(x: size.width*0.45, y: size.height*0.43)
        context.fill(Path(CGRect(origin: .zero, size: size)),
                     with: .radialGradient(Gradient(colors: [primary.opacity(0.08+motion.level*0.14), blue.opacity(0.07+motion.level*0.07), .black]),
                                           center: center, startRadius: 0, endRadius: size.height*0.6))
        drawStars(context: &context, size: size, dim: 1, skyFraction: 1)
    }

    private func drawStars(context: inout GraphicsContext, size: CGSize, dim: Double, skyFraction: Double) {
        let blue = Color(red: 0.15, green: 0.36, blue: 0.9)
        func random(_ value: Double) -> Double {
            let n = sin(value*127.1+311.7)*43758.5453
            return n-floor(n)
        }
        context.blendMode = .plusLighter
        for i in 0..<200 {
            if skyFraction < 1 && random(Double(i)+311) < 0.25 { continue }
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
            guard center.y < size.height*skyFraction else { continue }
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
                light = (0.08+1.5*pow(0.5+0.5*sin(motion.time*(1.8+seed*2)+seed*71),2))*(0.55+motion.level*1.3)
            } else if behavior >= 0.8 {
                light = 0.06+pulse*(2.2+motion.level*3.0)
            }
            let alpha = min((0.35+seed*0.45)*light*dim,1)
            let colorSeed = random(Double(i)+109)
            let artwork = skyFraction < 1 ? Color(red: 0.52, green: 0.72, blue: 1)
                : colorSeed < 0.6 ? primary : secondary
            let temperature = skyFraction < 1 ? blue
                : colorSeed < 0.55 ? blue : Color(red: 1,green: 0.3,blue: 0.2)
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
