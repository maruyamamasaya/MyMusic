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
        context.blendMode = .plusLighter
        let cyan = primary, violet = secondary
        let accent = Color(red: 1, green: 0.34, blue: 0.57)
        let drive = min(1,bass*0.32+mid*0.38+treble*0.18+beat*0.55)
        let width = Double(size.width), height = Double(size.height)
        let breath = Path(CGRect(origin: .zero, size: size))
        context.fill(breath, with: .linearGradient(
            Gradient(colors: [violet.opacity(0.018+drive*0.025),
                              cyan.opacity(0.028+drive*0.06),
                              violet.opacity(0.016+drive*0.03)]),
            startPoint: CGPoint(x: 0,y: height*0.1),
            endPoint: CGPoint(x: width,y: height*0.9)))
        func random(_ value: Double) -> Double {
            let raw = sin((value+worldSeed)*127.1+311.7)*43758.5453
            return raw-floor(raw)
        }
        func waveValue(_ x: Double) -> Double {
            guard waveform.count >= 48 else { return 0 }
            let position = min(max(x,0),1)*47
            let i = min(Int(position),46)
            return Double(waveform[i])*(1-(position-Double(i)))
                + Double(waveform[i+1])*(position-Double(i))
        }
        let amplitude = height*(0.12+ambient*0.022+bass*0.042+beat*0.05)
        if burstAge < 0.9 {
            let variant = VisualizerRipplePattern.index(bass: burstBass, mid: burstMid,
                                                        treble: burstTreble, serial: burstSerial)
            let amount = max(burstBass,burstMid,burstTreble)*pow(1-burstAge/0.9,1.5)
            let tint = burstBass >= burstMid && burstBass >= burstTreble ? cyan
                : burstMid >= burstTreble ? violet : accent
            let radius = height*(0.025+burstAge*(variant == 6 ? 0.86 : 0.69))
            let center = CGPoint(x: width*(variant == 6 ? (burstSerial.isMultiple(of: 2) ? -0.08 : 1.08)
                                  : variant == 7 ? 0.67 : 0.5),
                                 y: height*(variant == 4 ? 0.7 : variant == 7 ? 0.33 : 0.43))
            func ring(center: CGPoint, radius: Double, ellipse: Double = 1, fragments: Bool = false,
                      liquid: Bool = false, distortion: Bool = false) {
                var path = Path()
                for step in 0...96 {
                    let angle = Double(step)/96*2*Double.pi
                    let visible = !fragments || sin(angle*9+Double(burstSerial)*2.1) > 0.13
                    let variation = liquid ? sin(angle*5+burstAge*7)*height*0.025
                        + sin(angle*11-burstAge*4)*height*0.009
                        : distortion ? sin(angle*4+burstAge*5)*height*0.05 : 0
                    let point = CGPoint(x: center.x+cos(angle)*(radius+variation)/ellipse,
                                        y: center.y+sin(angle)*(radius+variation)*ellipse)
                    if step == 0 || !visible { path.move(to: point) }
                    else { path.addLine(to: point) }
                }
                context.stroke(path,with: .color(tint.opacity(amount*0.085)),lineWidth: height*0.042)
                context.stroke(path,with: .color(tint.opacity(amount*0.28)),lineWidth: height*0.009)
            }
            switch variant {
            case 1: ring(center: center,radius: radius,ellipse: 1.33)
            case 2: ring(center: center,radius: radius,fragments: true)
            case 3:
                ring(center: center,radius: radius)
                ring(center: CGPoint(x: width*0.18,y: height*0.62),radius: radius*0.91)
            case 4:
                for spoke in 0..<16 {
                    let angle = Double(spoke)/16*2*Double.pi
                    var ray = Path()
                    ray.move(to: CGPoint(x: center.x+cos(angle)*radius*0.56,
                                         y: center.y+sin(angle)*radius*0.56))
                    ray.addLine(to: CGPoint(x: center.x+cos(angle)*radius*1.3,
                                            y: center.y+sin(angle)*radius*1.3))
                    context.stroke(ray,with: .color(tint.opacity(amount*0.25)),lineWidth: height*0.003)
                }
            case 5: ring(center: center,radius: radius,liquid: true)
            case 6:
                var front = Path()
                let sign = center.x < 0 ? 1.0 : -1.0
                for step in 0...32 {
                    let y = height*Double(step)/32
                    let x = center.x+sign*radius+sin(Double(step)*0.37+burstAge*9)*height*0.014
                    if step == 0 { front.move(to: CGPoint(x: x,y: y)) }
                    else { front.addLine(to: CGPoint(x: x,y: y)) }
                }
                context.stroke(front,with: .color(tint.opacity(amount*0.18)),lineWidth: height*0.032)
                context.stroke(front,with: .color(tint.opacity(amount*0.32)),lineWidth: height*0.006)
            case 7: ring(center: center,radius: radius,distortion: true)
            default: ring(center: center,radius: radius)
            }
        }
        var trace = Path(), echo = Path()
        for i in 0..<48 {
            let x = width*Double(i)/47
            let sample = min(1,max(-1,Double(waveform[i])))
            let point = CGPoint(x: x,y: height*0.43+sample*amplitude)
            let shadow = CGPoint(x: x,y: height*0.51-sample*amplitude*0.54)
            if i == 0 { trace.move(to: point); echo.move(to: shadow) }
            else { trace.addLine(to: point); echo.addLine(to: shadow) }
        }
        let waveLight = 0.45+drive*0.55
        context.stroke(trace,with: .color(cyan.opacity(0.05*waveLight)),lineWidth: 25+drive*17)
        context.stroke(trace,with: .color(violet.opacity(0.17*waveLight)),lineWidth: 8+drive*7)
        context.stroke(trace,with: .linearGradient(
            Gradient(colors: [cyan,violet,accent]),startPoint: .zero,
            endPoint: CGPoint(x: width,y: 0)),lineWidth: 3.1+drive*1.3)
        context.stroke(trace,with: .color(.white.opacity(0.66*waveLight)),lineWidth: 1.3+drive*0.6)
        context.stroke(echo,with: .color(violet.opacity(0.07+ambient*0.045+beat*0.08)),lineWidth: 1.3)
        if drive > 0.08 {
            for sign in [-1.0,1.0] {
                var fiber = Path()
                for i in 0..<48 {
                    let x = width*Double(i)/47
                    let y = height*0.43+Double(waveform[i])*amplitude+sign*height*(0.008+drive*0.01)
                    if i == 0 { fiber.move(to: CGPoint(x: x,y: y)) }
                    else { fiber.addLine(to: CGPoint(x: x,y: y)) }
                }
                context.stroke(fiber,with: .color(cyan.opacity(drive*0.08)),lineWidth: 1)
            }
        }
        for index in 0..<24 {
            let response = index < bands.count ? min(1,max(0,Double(bands[index]))) : 0
            let frequency = (Double(index)+0.5)/24
            let range = frequency < 0.33 ? bass : frequency < 0.7 ? mid : treble
            let low = max(0,min(1,(0.42-frequency)/0.2))
            let high = max(0,min(1,(frequency-0.64)/0.2))
            let plumeHeight = height*(0.08+pow(min(1,response+range*0.14),0.8) *
                                      (0.19+energy*0.13))*(1+low*0.27-high*0.22)
            let x = width*(Double(index)+0.5)/24
            let source = height*0.43+waveValue((Double(index)+0.5)/24)*amplitude
            let direction = index.isMultiple(of: 2) ? -1.0 : 1.0
            let top = source+direction*plumeHeight
            let tint = frequency < 0.52 ? cyan : frequency < 0.76 ? violet : accent
            let spread = width/24*(0.28+low*0.38-high*0.16+electronic*0.07)
            let plume = Path(ellipseIn: CGRect(x: x-spread*1.6,y: top-height*0.025,
                                               width: spread*3.2,height: height*0.05))
            context.fill(plume,with: .radialGradient(
                Gradient(colors: [tint.opacity((0.08+drive*0.1)*response),.clear]),
                center: CGPoint(x: x,y: top),startRadius: 0,endRadius: spread*2.2))
            var filament = Path()
            filament.move(to: CGPoint(x: x,y: source))
            filament.addQuadCurve(to: CGPoint(x: x,y: top),
                                  control: CGPoint(x: x+sin(Double(index)*0.63-motion.time*2)
                                                    * spread * (1-low) * 1.1,y: (source+top)*0.5))
            let light = (0.18+response*0.66)*(0.58+brightness*0.3+drive*0.32)
            context.stroke(filament,with: .color(tint.opacity(light*0.075)),
                           lineWidth: spread*(1.1+low*0.5))
            context.stroke(filament,with: .color(tint.opacity(light*0.43)),
                           lineWidth: spread*(0.28+low*0.22))
            context.stroke(filament,with: .color(.white.opacity(response*light*0.14)),lineWidth: 0.7)
        }
        for index in 0..<48 {
            let seed = random(Double(index)+7)
            let family = random(Double(index)+113)
            let velocity = 0.66+seed*0.8+(family > 0.68 ? treble*0.75 : bass*0.16)
            let time = motion.time
            let impulse = burstAge < 0.9 ? exp(-burstAge*(family < 0.32 ? 3 : 5.5)) *
                max(burstBass,burstMid,burstTreble) : 0
            let flow = time*0.013*velocity+sin(time*0.31+Double(index))*0.009
            let x = (random(Double(index)+19)+flow
                + cos(seed*23+Double(index))*impulse*(family > 0.68 ? 0.055 : 0.022))
                .truncatingRemainder(dividingBy: 1)
            let waveY = height*0.43+waveValue(x)*amplitude
            let freeY = height*(0.08+random(Double(index)+37)*0.84)
            let capture = (family < 0.32 ? 0.12 : family < 0.7 ? 0.53 : 0.27)+drive*0.14
            let orbit = height*(sin(time*(0.19+seed*0.27)+Double(index)*1.7)*0.055
                               + sin(time*(0.43+seed*0.24)+Double(index)*0.9)*0.022)
            let magneticStrength = family < 0.32 ? 0.35 : 1.0
            let magnetic = height*sin(x*18-time*0.57+Double(index))*0.023*magneticStrength
            let scatterStrength = family > 0.68 ? 0.18 : 0.075
            let scatter = height*sin(seed*31+Double(index)*1.7)*impulse*scatterStrength
            let point = CGPoint(x: width*x,y: freeY*(1-capture)+waveY*capture+orbit+magnetic+scatter)
            let radius = family < 0.32 ? 1.3+bass*0.7 : family < 0.7 ? 0.9+mid*0.35 : 0.55+treble*0.25
            let tint = index.isMultiple(of: 3) ? accent : index.isMultiple(of: 2) ? cyan : violet
            let amount = min(1,0.25+drive*0.33+impulse*0.43
                + (family < 0.32 ? bass : family < 0.7 ? mid : treble)*0.33)
            let core = Path(ellipseIn: CGRect(x: point.x-radius,y: point.y-radius,
                                              width: radius*2,height: radius*2))
            let halo = Path(ellipseIn: CGRect(x: point.x-radius*5,y: point.y-radius*5,
                                              width: radius*10,height: radius*10))
            context.fill(halo,with: .radialGradient(
                Gradient(colors: [tint.opacity(amount*0.22),.clear]),
                center: point,startRadius: 0,endRadius: radius*5))
            context.fill(core,with: .color(.white.opacity(amount*0.75)))
        }
        if burstAge < 0.95 {
            let fade = pow(1-burstAge/0.95,1.4)
            for index in 0..<24 {
                let layer = index % 3
                let strength = layer == 0 ? burstBass : layer == 1 ? burstMid : burstTreble
                guard strength >= 0.08 else { continue }
                let key = Double(index)+Double(burstSerial)*31
                let seed = random(key+11)
                let bandX = (Double(index)+0.5)/24
                let bandLevel = index < bands.count ? Double(bands[index]) : 0
                let origin: CGPoint = switch index % 5 {
                case 0: CGPoint(x: width*bandX,y: height*0.43+waveValue(bandX)*amplitude)
                case 1: CGPoint(x: width*bandX,y: height*(0.79-bandLevel*0.27))
                case 2: CGPoint(x: -width*0.01,y: height*(0.20+seed*0.6))
                case 3: CGPoint(x: width*1.01,y: height*(0.12+seed*0.7))
                default: CGPoint(x: width*bandX,y: height*0.94)
                }
                let angle = random(key+29)*2*Double.pi
                let depth = 0.45+random(key+47)*1.15
                let speed = (layer == 0 ? 0.30 : layer == 1 ? 0.51 : 0.77)*depth
                let point = CGPoint(x: origin.x+cos(angle)*height*speed*burstAge,
                                    y: origin.y+sin(angle)*height*speed*burstAge -
                                        height*0.035*burstAge*burstAge)
                let radius = height*(layer == 0 ? 0.006 : layer == 1 ? 0.0037 : 0.0021)*depth
                let tint = layer == 0 ? cyan : layer == 1 ? violet : accent
                let amount = min(1,strength*fade*(0.55+bandLevel*0.45))
                let halo = Path(ellipseIn: CGRect(x: point.x-radius*4,y: point.y-radius*4,
                                                  width: radius*8,height: radius*8))
                let core = Path(ellipseIn: CGRect(x: point.x-radius,y: point.y-radius,
                                                  width: radius*2,height: radius*2))
                context.fill(halo,with: .radialGradient(
                    Gradient(colors: [tint.opacity(amount*0.24),.clear]),
                    center: point,startRadius: 0,endRadius: radius*4))
                context.fill(core,with: .color(.white.opacity(amount*0.6)))
            }
        }
    }

    private func plasmaSpark(context: inout GraphicsContext, size: CGSize) {
        context.opacity = subdued ? 0.4 : 1
        guard burstAge < 0.43 else { return }
        let strength = max(burstBass, burstMid, burstTreble)
        guard strength >= 0.12 else { return }
        let kind = burstBass >= burstMid && burstBass >= burstTreble ? 0
            : (burstMid >= burstTreble ? 1 : 2)
        let points = PlasmaSparkPattern.points(seed: worldSeed, serial: burstSerial, mid: burstMid)
            .map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        let height = Double(size.height)
        let flash = (1-exp(-burstAge/0.008))
            * exp(-burstAge*(kind == 0 ? 10 : kind == 1 ? 12 : 16))
        let light = min(1, strength * flash)
        let progress = min(1, burstAge / 0.052)
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
                       style: StrokeStyle(lineWidth: height*0.11,lineCap: .round,lineJoin: .round))
        context.stroke(line, with: ion,
                       style: StrokeStyle(lineWidth: height*0.020,lineCap: .round,lineJoin: .round))
        context.stroke(line, with: .color(.white.opacity(light)),
                       style: StrokeStyle(lineWidth: height*(kind == 0 ? 0.0065 : kind == 1 ? 0.0045 : 0.0028),
                                          lineCap: .round,lineJoin: .round))
        if kind == 2 && burstAge < 0.18 && progress > 0.65 {
            let base = points[5]
            let dx = points[6].x-points[4].x, dy = points[6].y-points[4].y
            let length = max(1,hypot(dx,dy))
            let tip = CGPoint(x: base.x+dx/length*height*0.035-dy/length*height*0.067,
                              y: base.y+dy/length*height*0.035+dx/length*height*0.067)
            var branch = Path()
            branch.move(to: base); branch.addLine(to: tip)
            let amount = min(1,strength*exp(-burstAge*21))
            context.stroke(branch,with: .color(rose.opacity(amount*0.32)),lineWidth: height*0.010)
            context.stroke(branch,with: .color(.white.opacity(amount*0.75)),lineWidth: height*0.002)
        }
        for index in 0..<6 {
            let vertex = 1+(index*5)%7
            guard Double(vertex)/8 <= progress else { continue }
            let source = points[vertex]
            let drift = burstAge*height*0.18
            let phase = Double(index*37+burstSerial*11)
            let point = CGPoint(x: source.x+sin(phase)*drift*0.5,
                                y: source.y+cos(phase*1.7)*drift*0.5)
            let amount = min(1,strength*exp(-burstAge*19))
            let radius = height*0.0018
            let halo = Path(ellipseIn: CGRect(x: point.x-radius*5,y: point.y-radius*5,
                                              width: radius*10,height: radius*10))
            let core = Path(ellipseIn: CGRect(x: point.x-radius,y: point.y-radius,
                                              width: radius*2,height: radius*2))
            context.fill(halo,with: .radialGradient(
                Gradient(colors: [(index.isMultiple(of: 2) ? cyan : rose).opacity(amount*0.24),.clear]),
                center: point,startRadius: 0,endRadius: radius*5))
            context.fill(core,with: .color(.white.opacity(amount*0.8)))
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
