import SwiftUI

/// Lightweight Canvas fallback when Metal is unavailable.
struct VisualWorldScene: View {
    let style: VisualWorldStyle
    let primary: Color
    let secondary: Color
    let motion: VisualWorldDynamics
    var worldSeed = 0.0
    var profile = TrackVisualProfile()
    private var energy: Double { Double(profile.energy) }
    private var ambient: Double { Double(profile.atmospheric) }
    private var brightness: Double { Double(profile.brightness) }
    private var aggressive: Double { Double(profile.aggression) }
    private var electronic: Double { Double(profile.rhythmicity) }
    var bands = [Float](repeating: 0, count: 24)
    var waveform = [Float](repeating: 0, count: 48)
    var bass = 0.0
    var mid = 0.0
    var treble = 0.0
    var beat = 0.0
    var burstAge = 2.0
    var burstBass = 0.0
    var burstMid = 0.0
    var burstTreble = 0.0
    var burstSerial = 0
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
            for index in 0..<Int(120 + profile.density * 40) {
                let seed = Double(index) * 2.399963
                let z = 1 - 2 * (Double(index)+0.5)/Double(Int(120 + profile.density * 40))
                let radial = sqrt(max(0,1-z*z))
                let angle = seed + motion.time * 0.3 * Double(profile.motionSpeed)
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

    private func spherePhotons(context: inout GraphicsContext, size: CGSize) {
        let unit = min(size.width, size.height) * 0.5
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.43)
        func seed(_ i: Int, _ offset: Double) -> Double {
            let value = sin((Double(i) + offset + worldSeed) * 127.1 + 311.7) * 43758.5453
            return value - floor(value)
        }
        context.blendMode = .plusLighter
        for i in 0..<Int(12 + profile.density * 4) {
            let value = seed(i, 3)
            let time = motion.time
            let phase = value*2*Double.pi + time*Double(profile.motionSpeed)*(0.26+seed(i, 51)*0.26)*(i % 3 == 0 ? -1 : 1)
                + sin(time*(0.16+value*0.12)+value*21)*0.24
                + sin(time*(0.38+value*0.2)+value*33)*0.08
            let point = CGPoint(x: center.x + unit*(cos(phase)*(0.84+value*0.1)
                + sin(time*(0.43+value*0.23)+value*17)*0.035),
                                y: center.y + unit*(sin(phase)*(0.98+value*0.14)
                + cos(time*(0.29+value*0.18)+value*39)*0.06))
            let radius = unit*(0.0025+seed(i, 87)*0.0032)*(1.25-Double(profile.trebleWeight)*0.5)
            let shimmer = 0.25+0.75*pow(0.5+0.5*sin(time*(1.2+value*4)+value*41),3)
            let color = i.isMultiple(of: 2) ? primary : secondary
            let dot = Path(ellipseIn: CGRect(x: point.x-radius, y: point.y-radius,
                                            width: radius*2, height: radius*2))
            context.fill(dot, with: .color(color.opacity(min(1,shimmer*(0.7+motion.level*0.4)))))
            context.fill(dot, with: .color(.white.opacity(min(1,shimmer*(0.25+motion.level*0.3)))))
        }
    }

    private func sphereSatellites(context: inout GraphicsContext, size: CGSize) {
        let unit = min(size.width, size.height) * 0.5
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.43)
        func seed(_ i: Int, _ offset: Double) -> Double {
            let value = sin((Double(i) + offset + worldSeed) * 127.1 + 311.7) * 43758.5453
            return value - floor(value)
        }
        context.blendMode = .plusLighter
        spherePhotons(context: &context, size: size)
        for i in 0..<3 {
            let value = seed(i, 113)
            let time = motion.time
            let phase = value*2*Double.pi + time*Double(profile.motionSpeed)*(0.25+value*0.2)*(i == 1 ? -1 : 1)
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
        context.blendMode = .normal
        let width = Double(size.width), height = Double(size.height)
        let accent = Color(red: 1, green: 0.34, blue: 0.57)
        let tone = bass >= mid && bass >= treble ? primary : mid >= treble ? secondary : accent
        let light = 0.35+0.75*max(bass,mid,treble)
        let time = motion.time*4
        func lineY(_ x: Double) -> Double {
            let position = min(max(x,0),1)*47
            let index = min(Int(position),46)
            let fraction = position-Double(index)
            let sample = index+1 < waveform.count
                ? Double(waveform[index])*(1-fraction)+Double(waveform[index+1])*fraction : 0
            return height*(0.5+sample*(0.06+Double(profile.calmness)*0.035)
                + bass*(0.045+Double(profile.bassWeight)*0.046)*sin(x*12.566-time*0.8)
                + mid*0.027*sin(x*43.982-time*1.35)
                + treble*0.010*sin(x*119.38-time*2))
        }
        var trace = Path()
        for step in 0...96 {
            let x = Double(step)/96
            let point = CGPoint(x: width*x,y: lineY(x))
            if step == 0 { trace.move(to: point) } else { trace.addLine(to: point) }
        }
        context.drawLayer { glow in
            glow.addFilter(.blur(radius: 10))
            glow.stroke(trace,with: .color(tone.opacity(0.55*light)),lineWidth: 3)
        }
        context.stroke(trace,with: .color(tone.opacity(0.44*light)),lineWidth: 3)
        context.stroke(trace,with: .color(.white.opacity(min(1,0.72*light))),lineWidth: 1.4)

        if burstAge < 0.8 {
            let power = max(burstBass,burstMid,burstTreble)
            let radius = height*(0.02+burstAge*(burstBass >= burstMid && burstBass >= burstTreble ? 0.43+Double(profile.bassWeight)*0.23 : 0.43))
            let center = CGPoint(x: width*0.5,y: height*0.5)
            var ripple = Path()
            for step in 0...96 {
                let angle = Double(step)/96*2*Double.pi
                let point = CGPoint(x: center.x+cos(angle)*radius,
                                    y: center.y+sin(angle)*radius)
                if step == 0 { ripple.move(to: point) } else { ripple.addLine(to: point) }
            }
            let fade = min(1,power*pow(1-burstAge/0.8,2))
            context.stroke(ripple,with: .color(tone.opacity(fade*0.20)),lineWidth: 8)
            context.stroke(ripple,with: .color(tone.opacity(fade*0.28)),lineWidth: 1.4)
        }
        spherePhotons(context: &context,size: size)
    }

    private func plasmaSpark(context: inout GraphicsContext, size: CGSize) {
        context.opacity = subdued ? 0.4 : 1
        guard burstAge < 0.43 else { return }
        let chance = min(1, max(0, 0.25 + aggressive*0.45 + energy*0.2 - Double(profile.calmness)*0.15))
        let raw = sin(Double(burstSerial)*73.19 + worldSeed*0.17)*43758.5453
        guard raw-floor(raw) <= chance else { return }
        let strength = max(burstBass, burstMid, burstTreble)
        guard strength >= 0.12 else { return }
        let kind = burstBass >= burstMid && burstBass >= burstTreble ? 0
            : (burstMid >= burstTreble ? 1 : 2)
        let points = PlasmaSparkPattern.points(seed: worldSeed, serial: burstSerial, mid: burstMid)
            .map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        let height = Double(size.height)
        let flash = (1-exp(-burstAge/0.008))
            * exp(-burstAge*(kind == 0 ? 10 : kind == 1 ? 12 : 16))
        let light = min(1, strength * flash * (0.65+Double(profile.turbulence)*0.4))
        let progress = min(1, burstAge / (0.07-0.025*Double(profile.motionSpeed)))
        let full = progress * 8
        var line = Path()
        line.move(to: points[0])
        for index in 0..<8 {
            guard Double(index) < full else { break }
            let fraction = min(1, full-Double(index))
            let start = points[index], end = points[index+1]
            line.addLine(to: CGPoint(x: start.x+(end.x-start.x)*fraction,
                                     y: start.y+(end.y-start.y)*fraction))
        }
        let violet = Color(red: 0.43, green: 0.12, blue: 0.94)
        let cyan = Color(red: 0.08, green: 0.74, blue: 1)
        let rose = Color(red: 1, green: 0.13, blue: 0.55)
        context.blendMode = .plusLighter
        let ion = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [violet.opacity(light),cyan.opacity(light),rose.opacity(light*0.65)]),
            startPoint: points[0], endPoint: points[8])
        context.stroke(line, with: .color(violet.opacity(light*0.065)),
                       style: StrokeStyle(lineWidth: height*0.035,lineCap: .round,lineJoin: .round))
        context.stroke(line, with: ion,
                       style: StrokeStyle(lineWidth: height*0.006,lineCap: .round,lineJoin: .round))
        context.stroke(line, with: .color(.white.opacity(light)),
                       style: StrokeStyle(lineWidth: height*(kind == 0 ? 0.0019 : kind == 1 ? 0.0014 : 0.001),
                                          lineCap: .round,lineJoin: .round))
        if burstAge < 0.25 {
            let forks = PlasmaSparkPattern.branches(seed: worldSeed, serial: burstSerial,
                                                     mid: burstMid)
            for index in 0..<2 {
                let response = index == 0 ? strength : max(burstMid,burstTreble,strength*0.55)
                guard response >= 0.12, progress > (index == 0 ? 0.35 : 0.7) else { continue }
                let vertices = forks[index].map { CGPoint(x: $0.x*size.width,y: $0.y*size.height) }
                var branch = Path()
                branch.move(to: vertices[0])
                for vertex in vertices.dropFirst() { branch.addLine(to: vertex) }
                let amount = min(1,response*exp(-burstAge*10))
                let tint = index == 0 ? cyan : rose
                context.stroke(branch,with: .color(tint.opacity(amount*0.48)),
                               style: StrokeStyle(lineWidth: height*0.003,lineCap: .round,lineJoin: .round))
                context.stroke(branch,with: .color(.white.opacity(amount*0.88)),
                               style: StrokeStyle(lineWidth: height*0.0009,lineCap: .round,lineJoin: .round))
            }
        }
        func chargeSeed(_ value: Double) -> Double {
            let raw = sin((value+worldSeed)*127.1+Double(burstSerial)*31.3)*43758.5453
            return raw-floor(raw)
        }
        for index in 0..<12 {
            let vertex = 1+(index*5)%7
            guard Double(vertex)/8 <= progress+0.1 else { continue }
            let seed = chargeSeed(Double(index)+73)
            let source = points[vertex]
            let dx = points[vertex+1].x-points[vertex-1].x
            let dy = points[vertex+1].y-points[vertex-1].y
            let length = max(1,hypot(dx,dy))
            let orbit = height*(0.005+seed*0.008)
            let phase = seed*2*Double.pi+burstAge*(9+seed*7)
            var point = CGPoint(x: source.x-dy/length*(seed-0.5)*height*0.035+cos(phase)*orbit,
                                y: source.y+dx/length*(seed-0.5)*height*0.035+sin(phase)*orbit)
            let flying = index.isMultiple(of: 4)
            if flying {
                point.x += (chargeSeed(Double(index)+7)-0.5)*burstAge*height*0.4
                point.y += (chargeSeed(Double(index)+17)-0.5)*burstAge*height*0.4
            }
            let shimmer = 0.25+0.75*pow(0.5+0.5*sin(burstAge*(12+seed*8)+seed*41),3)
            let amount = min(1,strength*exp(-burstAge*(flying ? 14 : 18))*shimmer)
            let radius = height*(0.0012+seed*0.0018)
            let halo = Path(ellipseIn: CGRect(x: point.x-radius*5,y: point.y-radius*5,
                                              width: radius*10,height: radius*10))
            let core = Path(ellipseIn: CGRect(x: point.x-radius,y: point.y-radius,
                                              width: radius*2,height: radius*2))
            let tint = index.isMultiple(of: 5) ? rose : seed < 0.5 ? violet : cyan
            context.fill(halo,with: .radialGradient(
                Gradient(colors: [tint.opacity(amount*0.18),.clear]),
                center: point,startRadius: 0,endRadius: radius*5))
            context.fill(core,with: .color(tint.opacity(amount*0.55)))
            context.fill(core,with: .color(.white.opacity(amount*0.55)))
        }
    }

    private func lightGates(context: inout GraphicsContext, size: CGSize) {
        context.opacity = subdued ? 0.4 : 1
        context.blendMode = .plusLighter
        let unit = min(size.width,size.height)*0.5
        let center = CGPoint(x: size.width*0.5, y: size.height*0.43)
        for index in 0..<8 {
            let phase = (Double(index)+0.5)/8-motion.time*0.32*Double(profile.motionSpeed)
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
            let drift = motion.time * Double(profile.motionSpeed) * (0.5 + energy*0.55 + Double(layer) * 0.45)
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
        for i in 0..<Int(160 + profile.density * 40) {
            if skyFraction < 1 && random(Double(i)+311) < 0.25 { continue }
            let seed = random(Double(i))
            let depth = random(Double(i)+227)
            let driftPhase = random(Double(i)+239)*2*Double.pi
            let rate = (0.18+random(Double(i)+251)*0.12)*(1+depth*0.36)
            let driftRadius = 0.002+depth*0.006
            let driftX = sin(motion.time*rate+driftPhase)*driftRadius
            let driftY = cos(motion.time*rate*0.73+driftPhase*1.7)*driftRadius
            let x = (random(Double(i)+41+worldSeed) + motion.time*0.0008*Double(profile.motionSpeed) + driftX + 1).truncatingRemainder(dividingBy: 1)
            let y = random(Double(i)+97+worldSeed) + driftY
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
