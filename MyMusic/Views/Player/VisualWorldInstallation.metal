#include <metal_stdlib>
using namespace metal;

struct WorldUniforms {
    float4 viewport, motion, sound, character, tonal;
    float4 primary, secondary, accent;
    float4 material, layout, spatial, burst;
    float4 plasma0, plasma1, plasma2, plasma3, plasma4;
    float4 band0, band1, band2, band3, band4, band5;
    float4 wave0, wave1, wave2, wave3, wave4, wave5;
    float4 wave6, wave7, wave8, wave9, wave10, wave11;
};
struct Raster { float4 position [[position]]; float2 uv; };
vertex Raster visualWorldVertex(uint id [[vertex_id]]) {
    float2 uv = float2((id << 1) & 2, id & 2);
    return {float4(uv * 2 - 1, 0, 1), float2(uv.x, 1 - uv.y)};
}
// A single luminous volume. No frames, orbital rings, repeated geometry or background objects.
float random3(float3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}
float field(float3 p) {
    float3 i = floor(p), f = fract(p);
    f = f * f * (3 - 2 * f);
    return mix(mix(mix(random3(i), random3(i + float3(1,0,0)), f.x),
                   mix(random3(i + float3(0,1,0)), random3(i + float3(1,1,0)), f.x), f.y),
               mix(mix(random3(i + float3(0,0,1)), random3(i + float3(1,0,1)), f.x),
                   mix(random3(i + float3(0,1,1)), random3(i + float3(1,1,1)), f.x), f.y), f.z);
}
float3 turn(float3 p, float a) {
    float c = cos(a), s = sin(a);
    return float3(c*p.x+s*p.z, p.y, -s*p.x+c*p.z);
}
float spectrum(float p, constant WorldUniforms &u) {
    int i = clamp(int(p * 24), 0, 23);
    float4 bands[6] = {u.band0,u.band1,u.band2,u.band3,u.band4,u.band5};
    return bands[i/4][i%4];
}
float waveformSample(int index, constant WorldUniforms &u) {
    int i = clamp(index,0,47);
    float4 samples[12] = {u.wave0,u.wave1,u.wave2,u.wave3,u.wave4,u.wave5,
                          u.wave6,u.wave7,u.wave8,u.wave9,u.wave10,u.wave11};
    return samples[i/4][i%4];
}
// Shared stars keep the same density and identities in Cosmos and Twilight.
float3 starField(float2 uv, constant WorldUniforms &u, float intensity, float coolness) {
    if (intensity < 1 && uv.y > 0.84) return float3(0);
    float aspect = u.viewport.x / u.viewport.y;
    float2 p = (uv - 0.5) * float2(aspect, 1);
    float t = u.viewport.z;
    float2 drift = float2(t * (0.002 + u.character.x * 0.002), sin(t * 0.08) * 0.009);
    float3 color = 0;
    int layers = u.tonal.w > 0.5 ? 2 : 3;
    for (int layer = 0; layer < layers; ++layer) {
        float depth = float(layer);
        float scale = 31 - depth * 8;
        float2 coordinates = (p + drift * (0.3 + depth * 0.45)) * scale;
        float2 cell = floor(coordinates);
        float2 local = fract(coordinates);
        // Neighbour cells keep soft star halos continuous at cell boundaries.
        for (int y=-1; y<=1; ++y) for (int x=-1; x<=1; ++x) {
            float2 offset = float2(x,y);
            float3 key = float3(cell + offset, depth * 19 + 5);
            float seed = random3(key);
            if (seed < 0.73 + depth * 0.045 + (intensity < 1 ? 0.06 : 0)) continue;
            float2 center = float2(random3(key+17),random3(key+37));
            float driftPhase = random3(key+239)*6.283;
            float driftRate = (0.18+random3(key+251)*0.12)*(1+depth*0.18);
            float driftRadius = 0.10+depth*0.055;
            center += float2(sin(t*driftRate+driftPhase),
                             cos(t*driftRate*0.73+driftPhase*1.7))*driftRadius;
            float2 delta = (local - offset - center) / scale;
            float d = length(delta);
            // Independent seeds prevent the brightest stars from also always being the largest.
            float sizeSeed = random3(key+53);
            float behavior = random3(key+83);
            float colorSeed = random3(key+109);
            // Keep most stars fine; a stable minority provides size contrast.
            float largerStar = smoothstep(0.82,1.0,sizeSeed);
            float pixels = 0.45 + sizeSeed*0.28 + depth*0.035 + largerStar*0.85;
            float size = pixels / u.viewport.y;
            float core = exp(-d*d / (size*size));
            float response = spectrum(random3(key+137),u);
            float phase = fract((t*2.4)/(1.2+random3(key+151)*2.2)+random3(key+173));
            float pulse = smoothstep(0.0,0.1,phase)*(1-smoothstep(0.1,0.42,phase));
            float light = 0.85; // 45% remain steadily lit, independent of audio.
            if (behavior >= 0.45 && behavior < 0.8) {
                light = (0.08+1.5*pow(0.5+0.5*sin(t*(1.8+seed*2)+random3(key+191)*6.283),2.0))*(0.65+response*1.25);
            } else if (behavior >= 0.8) {
                light = 0.06+pulse*(2.2+response*3.0);
            }
            float halo = exp(-d/(size*2.2))*0.022;
            if (behavior >= 0.8) halo += exp(-d/(size*4.0))*pulse*0.11;
            float3 artwork = colorSeed < u.material.w ? u.primary.rgb : u.secondary.rgb;
            if (colorSeed > 0.9) artwork = u.accent.rgb;
            artwork /= max(max(artwork.r,artwork.g),max(artwork.b,0.12));
            float3 temperature = colorSeed < 0.55 ? float3(0.3,0.55,1) : float3(1,0.28,0.16);
            float3 starlight = mix(artwork,temperature,0.28);
            if (random3(key+211)>0.86) starlight = mix(starlight,float3(1),0.65);
            if (behavior >= 0.8) starlight = mix(starlight,float3(1),pulse*0.35);
            starlight = mix(starlight,float3(0.48,0.7,1),coolness);
            float power = (0.28+depth*0.22)*light;
            color += starlight*(core+halo)*power*2.1*intensity;
        }
    }
    return color;
}
// Blue Cosmos: stable star identities, slow bounded drift at three depths, and diffuse nebula.
float3 nightSky(float2 uv, constant WorldUniforms &u) {
    float aspect = u.viewport.x / u.viewport.y;
    float2 p = (uv - 0.5) * float2(aspect, 1);
    float t = u.viewport.z;
    float2 drift = float2(t * (0.002 + u.character.x * 0.002), sin(t * 0.08) * 0.009);
    float3 blue = float3(0.055, 0.18, 0.65);
    float3 tint = mix(blue, mix(u.primary.rgb,u.secondary.rgb,0.5), 0.32);
    float cloud = field(float3(p * 4 + drift, 7.2));
    float detail = field(float3(p * 10 - drift, 13.1));
    float lane = exp(-pow((p.x + p.y * 0.46 + (cloud-0.5)*0.24) * 4.5, 2));
    float haze = lane * pow(cloud * 0.7 + detail * 0.3, 2.2);
    float3 color = float3(0.0006,0.0012,0.004);
    color += tint * haze * (0.08 + u.sound.x * 0.16 + u.motion.w * 0.11);
    color += starField(uv,u,1,0);
    return color;
}
float tubeDistance(float2 p, float2 a, float2 b) {
    float2 ab = b-a;
    return length(p-a-ab*clamp(dot(p-a,ab)/max(dot(ab,ab),0.00001),0.0,1.0));
}
float gateShapeDistance(float2 q, int pattern) {
    float d = 100.0;
    if (pattern == 0) { // Crossing braces
        for (int side=-1; side<=1; side+=2) {
            float x = float(side);
            d = min(d,tubeDistance(q,float2(x*0.85,-1.1),float2(x*1.4,1.1)));
            d = min(d,tubeDistance(q,float2(x*1.4,-1.1),float2(x*0.85,1.1)));
        }
        d = min(d,tubeDistance(q,float2(-1.4,1.1),float2(1.4,1.1)));
        d = min(d,tubeDistance(q,float2(-1.4,-1.1),float2(1.4,-1.1)));
    } else if (pattern == 1) { // Diamond portal
        float2 left = float2(-1.5,0), top = float2(0,1.3);
        float2 right = float2(1.5,0), bottom = float2(0,-1.3);
        d = min(d,tubeDistance(q,left,top));
        d = min(d,tubeDistance(q,top,right));
        d = min(d,tubeDistance(q,right,bottom));
        d = min(d,tubeDistance(q,bottom,left));
    } else if (pattern == 2) { // Faceted hexagon
        float2 a = float2(-0.8,1.15), b = float2(0.8,1.15);
        float2 c = float2(1.5,0), e = float2(0.8,-1.15);
        float2 f = float2(-0.8,-1.15), g = float2(-1.5,0);
        d = min(d,tubeDistance(q,a,b)); d = min(d,tubeDistance(q,b,c));
        d = min(d,tubeDistance(q,c,e)); d = min(d,tubeDistance(q,e,f));
        d = min(d,tubeDistance(q,f,g)); d = min(d,tubeDistance(q,g,a));
    } else if (pattern == 3) { // Twin chevrons
        d = min(d,tubeDistance(q,float2(-1.5,1.15),float2(0,0.48)));
        d = min(d,tubeDistance(q,float2(0,0.48),float2(1.5,1.15)));
        d = min(d,tubeDistance(q,float2(-1.5,-1.15),float2(0,-0.48)));
        d = min(d,tubeDistance(q,float2(0,-0.48),float2(1.5,-1.15)));
        d = min(d,tubeDistance(q,float2(-1.5,-1.15),float2(-1.5,1.15)));
        d = min(d,tubeDistance(q,float2(1.5,-1.15),float2(1.5,1.15)));
    } else { // Stepped frame
        d = min(d,tubeDistance(q,float2(-1.5,-1.15),float2(-1.5,0.55)));
        d = min(d,tubeDistance(q,float2(-1.5,0.55),float2(-0.8,0.55)));
        d = min(d,tubeDistance(q,float2(-0.8,0.55),float2(-0.8,1.15)));
        d = min(d,tubeDistance(q,float2(-0.8,1.15),float2(1.5,1.15)));
        d = min(d,tubeDistance(q,float2(1.5,1.15),float2(1.5,-0.55)));
        d = min(d,tubeDistance(q,float2(1.5,-0.55),float2(0.8,-0.55)));
        d = min(d,tubeDistance(q,float2(0.8,-0.55),float2(0.8,-1.15)));
        d = min(d,tubeDistance(q,float2(0.8,-1.15),float2(-1.5,-1.15)));
    }
    return d;
}
// Pulse Neon: seeded shapes advance through the viewer. Each gate changes only
// while it is fully faded at the far end of its loop.
float3 lightGates(float2 uv, constant WorldUniforms &u) {
    float2 p = (uv-float2(0.5,0.43))*u.viewport.xy/min(u.viewport.x,u.viewport.y)*2;
    p.y = -p.y;
    float3 primary = max(u.primary.rgb,float3(0.015));
    float3 secondary = max(u.secondary.rgb,float3(0.015));
    float3 color = primary*0.002;
    float travel = u.viewport.z * 0.32;
    int count = u.tonal.w > 0.5 ? 6 : 10;
    for (int i=0; i<count; ++i) {
        float gatePhase = (float(i)+0.5)/float(count)-travel;
        float depth = fract(gatePhase);
        float scale = 1.0/(0.3+depth*9);
        float fade = smoothstep(0.0,0.07,depth)*(1-smoothstep(0.84,1.0,depth));
        float2 q = p/scale;
        float shapeSeed = random3(float3(float(i)+17,floor(gatePhase),u.tonal.z+41));
        int pattern = (int(shapeSeed*5.0)+i)%5;
        float distance = gateShapeDistance(q,pattern);
        float width = max(0.008,1.1/(u.viewport.y*scale));
        float core = exp(-pow(distance/width,2));
        float glow = exp(-distance/0.055)*0.3 + exp(-distance/0.2)*0.055;
        float3 hue = mix(primary,secondary,0.5+0.5*sin(depth*4+q.y*0.8));
        float response = spectrum(depth,u);
        float excitation = 0.65+response*1.25+u.motion.z*0.45;
        color += (hue*glow*(3.2+u.sound.x*2.4) + mix(hue,float3(1),0.72)*core*2)*fade*excitation;
    }
    // Dim converging road light describes forward travel without covering the opening.
    float horizonGlow = exp(-length(p)*3.5);
    color += mix(primary,secondary,0.5)*horizonGlow*(0.025+u.motion.w*0.11+u.motion.z*0.08);
    return color;
}
// Twilight: a slowly breathing horizon with cloud banks moving at different depths.
float3 twilightSky(float2 uv, constant WorldUniforms &u) {
    float t = u.viewport.z;
    float aspect = u.viewport.x / u.viewport.y;
    float2 p = float2((uv.x-0.5)*aspect, uv.y);
    float horizon = 0.79 + 0.009*sin(p.x*5.0+t*0.36);
    float distance = p.y-horizon;
    float3 midnight = float3(0.003,0.012,0.065);
    float3 deepBlue = float3(0.015,0.045,0.16);
    float3 blue = float3(0.035,0.09,0.24);
    float3 rose = float3(0.27,0.075,0.16);
    float3 amber = float3(0.95,0.37,0.11);
    float3 color = mix(midnight,deepBlue,smoothstep(0.05,0.7,p.y));
    color = mix(color,blue,smoothstep(0.56,0.8,p.y)*0.42);
    float warmth = saturate(0.35+u.character.x*0.25+u.sound.y*0.28+u.motion.w*0.24);
    color = mix(color,rose,smoothstep(0.75,0.88,p.y)*(0.24+warmth*0.32));
    float glow = exp(-pow(distance/0.047,2.0));
    float shimmer = 0.75 + u.sound.x*0.55 + u.motion.w*0.38 + u.motion.z*0.32;
    color += amber*glow*(0.12+warmth*0.18)*shimmer;
    float sunDistance = length(float2(p.x*0.8,distance*1.3));
    color += mix(rose,amber,0.62)*exp(-sunDistance*sunDistance/0.025)*0.1*shimmer;
    // Three horizontal noise fields make layered clouds without a repeating shape.
    float movement = 0.09+u.character.x*0.08;
    float farNoise = field(float3(p.x*5.5-t*movement,p.y*15.0,2.7));
    float middleNoise = field(float3(p.x*8.0+t*movement*1.4,p.y*21.0,8.3));
    float nearNoise = field(float3(p.x*12.0-t*movement*1.9,p.y*27.0,14.6));
    float farBand = exp(-pow((p.y-0.52-farNoise*0.055)/0.07,2.0));
    float middleBand = exp(-pow((p.y-0.65-middleNoise*0.045)/0.06,2.0));
    float nearBand = exp(-pow((p.y-0.78-nearNoise*0.045)/0.075,2.0));
    float farCloud = farBand*smoothstep(0.42,0.7,farNoise);
    float middleCloud = middleBand*smoothstep(0.38,0.72,middleNoise);
    float nearCloud = nearBand*smoothstep(0.37,0.7,nearNoise);
    color = mix(color,float3(0.025,0.055,0.16),farCloud*0.45);
    color = mix(color,float3(0.045,0.06,0.18),middleCloud*0.58);
    color = mix(color,float3(0.055,0.035,0.11),nearCloud*0.76);
    float cloudEdge = max(middleBand*smoothstep(0.57,0.77,middleNoise),
                          nearBand*smoothstep(0.56,0.76,nearNoise));
    color += amber*cloudEdge*glow*(0.08+u.sound.z*0.14)*shimmer;
    color *= 1.0-smoothstep(0.86,1.0,p.y)*0.52;
    float3 artwork = mix(u.primary.rgb,u.secondary.rgb,0.5);
    color += artwork*(glow*0.035+farCloud*0.016);
    color += starField(uv,u,0.55,0.6)*(1-smoothstep(0.74,0.84,p.y));
    return max(color,0.0);
}
// The nine vertices are selected from twenty authored silhouettes on the CPU.
float3 plasmaSpark(float2 uv, constant WorldUniforms &u) {
    float3 color = float3(0.0005,0.001,0.006);
    float age = u.burst.x;
    if (age >= 0.43) return color;
    float bass = u.burst.y, mid = u.burst.z, treble = u.burst.w;
    float strength = max(bass,max(mid,treble));
    if (strength < 0.12) return color;
    int kind = bass >= mid && bass >= treble ? 0 : mid >= treble ? 1 : 2;
    float aspect = u.viewport.x/u.viewport.y;
    float2 points[9] = {u.plasma0.xy,u.plasma0.zw,u.plasma1.xy,u.plasma1.zw,
                        u.plasma2.xy,u.plasma2.zw,u.plasma3.xy,u.plasma3.zw,u.plasma4.xy};
    float2 p = uv*float2(aspect,1);
    float distance = 2;
    float along = 0;
    float2 nearest = 0;
    for (int i=0; i<8; ++i) {
        float2 a = points[i]*float2(aspect,1);
        float2 b = points[i+1]*float2(aspect,1);
        float2 delta = b-a;
        float t = saturate(dot(p-a,delta)/max(dot(delta,delta),0.000001));
        float2 candidate = a+delta*t;
        float d = length(p-candidate);
        if (d < distance) { distance=d; along=(float(i)+t)/8.0; nearest=candidate; }
    }
    float progress = saturate(age/0.052);
    float reveal = 1-smoothstep(progress-0.08,progress+0.015,along);
    float flash = smoothstep(0,0.012,age)*exp(-age*(kind == 0 ? 10.0 : kind == 1 ? 12.0 : 16.0));
    float light = strength*flash*reveal;
    float3 violet = float3(0.38,0.08,0.9);
    float3 cyan = float3(0.04,0.7,1.0);
    float3 rose = float3(1.0,0.12,0.55);
    float3 hue = mix(violet,cyan,saturate(along*0.8+0.1));
    hue = mix(hue,rose,0.27*smoothstep(0.4,0.95,along));
    float width = kind == 0 ? 0.0037 : kind == 1 ? 0.0026 : 0.0016;
    float d2 = distance*distance;
    float aura = exp(-d2/0.0036);
    float ion = exp(-d2/(width*width*32.0));
    float core = exp(-d2/(width*width));
    color += hue*(aura*0.095+ion*0.73)*light;
    color += float3(1,0.96,1)*core*2.9*light;
    // The air only catches light during the initial flash.
    color += hue*exp(-dot(p-nearest,p-nearest)/0.026)*light*0.018;
    if (kind == 0) color += hue*exp(-dot(p-points[4]*float2(aspect,1),p-points[4]*float2(aspect,1))/0.1)*strength*exp(-age*35)*0.075;
    if (kind == 2 && age < 0.18) {
        float2 base = points[5]*float2(aspect,1);
        float2 tangent = normalize((points[6]-points[4])*float2(aspect,1));
        float2 side = float2(-tangent.y,tangent.x);
        float2 tip = base+tangent*0.035+side*0.067;
        float2 branch = tip-base;
        float t = saturate(dot(p-base,branch)/dot(branch,branch));
        float d = length(p-base-branch*t);
        float branchLight = strength*exp(-age*21)*smoothstep(0.025,0.065,age);
        color += rose*exp(-d*d/0.00009)*branchLight*0.31;
        color += float3(1)*exp(-d*d/0.000003)*branchLight*0.7;
    }
    int sparks = u.tonal.w > 0.5 ? 3 : 6;
    for (int i=0; i<sparks; ++i) {
        float key = float(i)+u.spatial.z*11;
        int pointIndex = 1+(i*5)%7;
        float2 point = points[pointIndex]*float2(aspect,1);
        point += float2(random3(float3(key,7,3))-0.5,random3(float3(key,17,9))-0.5)*age*0.18;
        float d2 = dot(p-point,p-point);
        float sparkLight = strength*exp(-age*19);
        color += mix(cyan,rose,float(i%2))*exp(-d2/0.00008)*sparkLight*0.23;
        color += float3(1)*exp(-d2/0.000003)*sparkLight*0.8;
    }
    return max(color,0.0);
}
// Eight deliberately different attack silhouettes, selected once per burst.
float3 visualizerRipple(float2 uv, constant WorldUniforms &u,
                        float3 cyan, float3 violet, float3 accent) {
    float age = u.burst.x;
    if (age >= 0.9) return float3(0);
    float bass = u.burst.y, mid = u.burst.z, high = u.burst.w;
    float power = max(bass,max(mid,high))*pow(1.0-age/0.9,1.5);
    if (power < 0.015) return float3(0);
    int variant = int(u.spatial.w+0.5);
    float aspect = u.viewport.x/u.viewport.y;
    float2 center = variant == 6 ? float2(u.spatial.z - 2.0*floor(u.spatial.z*0.5) < 0.5 ? -0.08 : 1.08,0.45)
                  : variant == 4 ? float2(0.5,0.7)
                  : variant == 7 ? float2(0.67,0.33) : float2(0.5,0.43);
    float2 delta = (uv-center)*float2(aspect,1);
    float r = length(delta);
    float theta = atan2(delta.y,delta.x);
    float radius = 0.025+age*(variant == 6 ? 0.86 : 0.69);
    float band = 0;
    if (variant == 0) band = exp(-pow((r-radius)/0.013,2.0));
    else if (variant == 1) {
        float ellipse = length(delta*float2(0.7,1.4));
        band = exp(-pow((ellipse-radius)/0.016,2.0));
    } else if (variant == 2) {
        float fragments = pow(max(0.0,sin(theta*9.0+u.spatial.z*2.1)),2.0);
        band = exp(-pow((r-radius)/0.011,2.0))*fragments;
    } else if (variant == 3) {
        float2 second = (uv-float2(0.18,0.62))*float2(aspect,1);
        band = exp(-pow((r-radius)/0.015,2.0))
             + exp(-pow((length(second)-radius*0.91)/0.014,2.0))*0.75;
        band *= 0.7+0.3*cos((r-length(second))*45.0);
    } else if (variant == 4) {
        float spokes = pow(max(0.0,cos(theta*14.0+u.spatial.z)),10.0);
        band = spokes*exp(-pow((r-radius)/0.085,2.0));
    } else if (variant == 5) {
        float liquid = r+sin(theta*5.0+age*7.0)*0.025+sin(theta*11.0-age*4.0)*0.009;
        band = exp(-pow((liquid-radius)/0.015,2.0));
    } else if (variant == 6) {
        float front = abs(delta.x)-radius;
        band = exp(-pow(front/0.025,2.0))
             * (0.4+0.6*exp(-pow(delta.y/0.52,2.0)));
    } else {
        float warped = r+sin(theta*4.0+age*5.0)*0.05;
        band = exp(-pow((warped-radius)/0.035,2.0))
             * (0.65+0.35*sin(theta*7.0+age*9.0));
    }
    float3 hue = bass >= mid && bass >= high ? cyan : mid >= high ? violet : accent;
    float atmosphere = exp(-pow((r-radius)/0.075,2.0))*0.045;
    return hue*(band*0.27+atmosphere)*power;
}
// The PCM waveform is a luminous body behind the 24-band spectrum. Seeded
// microphotons follow its energy without changing their identities each frame.
float3 musicVisualizer(float2 uv, constant WorldUniforms &u) {
    float beat = saturate(u.spatial.y);
    float energy = saturate(u.character.x);
    float ambient = saturate(u.character.z);
    float brightness = saturate(u.character.w);
    float aggressive = saturate(u.character.y);
    float electronic = saturate(u.material.y);
    float t = u.viewport.z*4.0;
    float drive = saturate(u.sound.x*0.32+u.sound.y*0.38+u.sound.z*0.18
                           +beat*0.55+u.motion.z*0.28);
    float3 cyan = mix(float3(0.015,0.45,0.78),max(u.primary.rgb,float3(0.025)),0.42);
    float3 violet = mix(float3(0.36,0.14,0.9),max(u.secondary.rgb,float3(0.025)),0.5);
    float3 accent = mix(float3(0.94,0.25,0.52),max(u.accent.rgb,float3(0.025)),0.38);
    float3 color = float3(0.001,0.003,0.013)*(1.0+brightness*0.5);
    float spatialBreath = sin(uv.x*12.0-u.viewport.z*1.5)*0.5+0.5;
    color += mix(cyan,violet,saturate(uv.y))*exp(-pow((uv.y-0.43)/0.37,2.0))
             *(0.012+drive*0.055+u.sound.x*0.025)*(0.72+spatialBreath*0.28);
    float burstAge = u.burst.x;
    float bassBurst = u.burst.y;
    float midBurst = u.burst.z;
    float highBurst = u.burst.w;
    float aspect = u.viewport.x/u.viewport.y;
    color += visualizerRipple(uv,u,cyan,violet,accent);

    // Three falloff scales make the actual PCM trace read as light, not a thin
    // graph line. The brightest core remains narrow enough to reveal its shape.
    {
        float position = saturate(uv.x)*47.0;
        int index = clamp(int(position),0,46);
        float fraction = smoothstep(0.0,1.0,fract(position));
        float sample = mix(waveformSample(index,u),waveformSample(index+1,u),fraction);
        float amplitude = 0.12+ambient*0.022+u.sound.x*0.042+beat*0.05;
        float waveY = 0.43+sample*amplitude;
        float d = abs(uv.y-waveY);
        float width = 0.00135+drive*0.00115;
        float waveCore = exp(-d*d/(width*width));
        float waveSheath = exp(-d*d/0.00011);
        float waveGlow = exp(-d*d/0.0023);
        float3 waveHue = mix(cyan,violet,0.5+sample*0.36);
        float waveLight = 0.42+drive*0.72+abs(sample)*0.27;
        color += waveHue*(waveSheath*0.42+waveGlow*0.075)*waveLight;
        color += mix(waveHue,float3(1),0.84)*waveCore*1.55*waveLight;
        float fiberOffset = 0.008+drive*0.01;
        float fibers = exp(-pow((d-fiberOffset)/(0.0018+drive*0.001),2.0));
        color += waveHue*fibers*drive*0.11;
        float echo = abs(uv.y-(0.51-sample*amplitude*0.54));
        color += violet*exp(-echo*echo/0.00016)*(0.045+ambient*0.04+beat*0.08);
    }

    // The spectrum grows out of the waveform. Each range has its own mass and
    // motion, so the 24 emitters read as one field rather than an EQ row.
    float barPosition = uv.x*24.0;
    if (barPosition >= 0.0 && barPosition < 24.0) {
      for (int neighbor=-1; neighbor<=1; ++neighbor) {
        int index = int(barPosition)+neighbor;
        if (index < 0 || index >= 24) continue;
        float frequency = (float(index)+0.5)/24.0;
        float response = spectrum(frequency,u);
        float rangeBoost = frequency < 0.33 ? u.sound.x*0.14
                         : frequency < 0.7 ? u.sound.y*0.12 : u.sound.z*0.14;
        float centerX = (float(index)+0.5)/24.0;
        float samplePosition = centerX*47.0;
        int sampleIndex = clamp(int(samplePosition),0,46);
        float waveValue = mix(waveformSample(sampleIndex,u),waveformSample(sampleIndex+1,u),fract(samplePosition));
        float sourceY = 0.43+waveValue*(0.12+ambient*0.022+u.sound.x*0.042+beat*0.05);
        float lowRange = 1.0-smoothstep(0.22,0.42,frequency);
        float highRange = smoothstep(0.64,0.84,frequency);
        float reach = (0.08+pow(saturate(response+rangeBoost),0.8)*(0.19+energy*0.13))
                      *(1.0+lowRange*0.27-highRange*0.22);
        float direction = index % 2 == 0 ? -1.0 : 1.0;
        float progress = saturate((uv.y-sourceY)*direction/max(reach,0.01));
        float sweep = sin(progress*4.5-t*(0.42+frequency*0.55)+float(index)*0.63)
                      *(0.006+u.sound.y*0.014)*(1.0-lowRange)*progress;
        float axis = centerX+sweep;
        float spread = (0.28+lowRange*0.38-highRange*0.16+electronic*0.07)/24.0;
        float taper = mix(1.0,0.18,progress);
        float filament = exp(-pow((uv.x-axis)/max(spread*taper,0.001),2.0));
        float body = smoothstep(-0.015,0.025,progress)*(1.0-smoothstep(0.82,1.08,progress));
        body *= step(0.0,(uv.y-sourceY)*direction)*step(abs(uv.y-sourceY),reach);
        float tip = exp(-pow((progress-0.93)/(0.08+lowRange*0.08),2.0))*filament*body;
        float glow = exp(-pow((uv.x-axis)/(spread*3.2),2.0))
                   *exp(-pow((progress-0.55)/0.55,2.0))*body;
        float3 hue = frequency < 0.52 ? mix(cyan,violet,frequency/0.52)
                                      : mix(violet,accent,(frequency-0.52)/0.48);
        float intensity = (0.18+response*0.66)*(0.58+brightness*0.3+drive*0.32);
        color += hue*(body*filament*(0.18+lowRange*0.22)+tip*0.54+glow*0.11)*intensity;
        color += float3(1)*tip*(0.07+aggressive*0.06+beat*0.16)*response;
      }
    }

    // Seeded carriers share an accelerating flow. A damped impulse scatters
    // them at attacks while a soft wave attraction bends their trajectories.
    float column = uv.x*32.0+t*0.013;
    int cell = int(floor(column));
    for (int offset=-1; offset<=1; ++offset) {
        float key = float(cell+offset);
        float seed = random3(float3(key,u.tonal.z,73));
        if (seed < (u.tonal.w > 0.5 ? 0.58 : 0.30)) continue;
        float family = random3(float3(key,u.tonal.z,119));
        float localTime = t*(0.72+seed*0.65);
        float flow = localTime*0.012+sin(localTime*0.31+key)*0.009;
        float impulse = burstAge < 0.9 ? exp(-burstAge*(family < 0.32 ? 3.0 : 5.5))
                        *max(bassBurst,max(midBurst,highBurst)) : 0.0;
        float photonX = (key+random3(float3(key,u.tonal.z,17)))/32.0
                      -flow/32.0
                      +sin(localTime*(0.26+seed*0.2)+key)*0.008
                      +cos(seed*23.0+key)*impulse*(family > 0.68 ? 0.055 : 0.022);
        if (photonX < -0.02 || photonX > 1.02) continue;
        float position = saturate(photonX)*47.0;
        int index = clamp(int(position),0,46);
        float sample = mix(waveformSample(index,u),waveformSample(index+1,u),fract(position));
        float waveY = 0.43+sample*(0.12+ambient*0.022+u.sound.x*0.042+beat*0.05);
        float freeY = 0.08+random3(float3(key,u.tonal.z,43))*0.84;
        float capture = (family < 0.32 ? 0.12 : family < 0.7 ? 0.53 : 0.27)+drive*0.14;
        float orbit = sin(localTime*(0.19+seed*0.27)+key*1.7)*0.047
                    +sin(localTime*(0.43+seed*0.24)+key*0.9)*0.02;
        float magnetic = sin(photonX*18.0-localTime*0.57+key)*0.023
                         *(family < 0.32 ? 0.35 : 1.0);
        float scatter = sin(seed*31.0+key*1.7)*impulse
                        *(family > 0.68 ? 0.18 : 0.075);
        float photonY = mix(freeY,waveY,capture)+orbit+magnetic+scatter;
        float2 delta = (uv-float2(photonX,photonY))*u.viewport.xy/u.viewport.y;
        float d2 = dot(delta,delta);
        float size = family < 0.32 ? 0.0017+u.sound.x*0.00085
                   : family < 0.7 ? 0.00125+u.sound.y*0.0004
                   : 0.0007+u.sound.z*0.0003;
        float core = exp(-d2/(size*size));
        float halo = exp(-d2/(size*size*40.0));
        float3 hue = mix(cyan,accent,random3(float3(key,u.tonal.z,91)));
        float light = 0.25+drive*0.33+impulse*0.43
                      +(family < 0.32 ? u.sound.x : family < 0.7 ? u.sound.y : u.sound.z)*0.33;
        color += hue*halo*0.16*light;
        color += mix(hue,float3(1),0.78)*core*1.7*light;
    }
    // One bounded burst follows each detected peak. Stable seeds give particles
    // different depths and launch sites while the recorded age drives the flight.
    if (burstAge < 0.95) {
        float fade = pow(1.0-burstAge/0.95,1.4);
        int count = u.tonal.w > 0.5 ? 12 : 24;
        for (int i=0; i<count; ++i) {
            float3 key = float3(float(i),u.tonal.z,u.spatial.z);
            float seed = random3(key+11);
            int layer = i % 3;
            float strength = layer == 0 ? bassBurst : layer == 1 ? midBurst : highBurst;
            if (strength < 0.08) continue;
            int site = i % 5;
            float bandX = (float(i)+0.5)/24.0;
            float bandLevel = spectrum((float(i)+0.5)/24.0,u);
            float samplePosition = bandX*47.0;
            int sampleIndex = clamp(int(samplePosition),0,46);
            float waveValue = mix(waveformSample(sampleIndex,u),waveformSample(sampleIndex+1,u),fract(samplePosition));
            float2 origin = site == 0 ? float2(bandX,0.43+waveValue*(0.12+ambient*0.022+u.sound.x*0.042+beat*0.05))
                          : site == 1 ? float2(bandX,0.79-bandLevel*0.27)
                          : site == 2 ? float2(-0.01,0.20+seed*0.6)
                          : site == 3 ? float2(1.01,0.12+seed*0.7)
                                      : float2(bandX,0.94);
            float angle = random3(key+29)*6.2831853;
            float depth = 0.45+random3(key+47)*1.15;
            float speed = (layer == 0 ? 0.30 : layer == 1 ? 0.51 : 0.77)*depth;
            float2 direction = float2(cos(angle),sin(angle));
            float2 point = origin+direction*speed*burstAge/float2(aspect,1);
            point += float2(0,-0.035*burstAge*burstAge);
            float2 delta = (uv-point)*float2(aspect,1);
            float d2 = dot(delta,delta);
            float size = (layer == 0 ? 0.006 : layer == 1 ? 0.0037 : 0.0021)*depth;
            if (d2 > size*size*100.0) continue;
            float core = exp(-d2/(size*size));
            float halo = exp(-d2/(size*size*20.0));
            float3 hue = layer == 0 ? cyan : layer == 1 ? violet : accent;
            float light = strength*fade*(0.55+bandLevel*0.45);
            color += hue*halo*0.22*light;
            color += mix(hue,float3(1),0.72)*core*1.7*light;
        }
    }
    return max(color,0.0);
}
// Stable per-track seeds vary each orbit's phase, speed and wobble without frame-to-frame jumps.
float3 sphereSatellites(float2 p, constant WorldUniforms &u) {
    float t = u.viewport.z;
    float r = length(p);
    float3 color = 0;
    if (r < 0.72 || r > 1.38) return color;
    int photons = u.tonal.w > 0.5 ? 9 : 16;
    for (int i=0; i<photons; ++i) {
        float seed = random3(float3(float(i)+3,u.tonal.z,23));
        float speed = 0.26+random3(float3(float(i)+51,u.tonal.z,17))*0.26;
        float direction = (i % 3 == 0) ? -1 : 1;
        float phase = seed*6.2831853+t*speed*direction
                    +sin(t*(0.16+seed*0.12)+seed*21)*0.24
                    +sin(t*(0.38+seed*0.2)+seed*33)*0.08;
        float2 center = float2(cos(phase)*(0.84+seed*0.1)
                                   +sin(t*(0.43+seed*0.23)+seed*17)*0.035,
                               sin(phase)*(0.98+seed*0.14)
                                   +cos(t*(0.29+seed*0.18)+seed*39)*0.06);
        float d = length(p-center);
        float size = 0.0025+random3(float3(float(i)+87,u.tonal.z,9))*0.0032;
        float shimmer = 0.25+0.75*pow(0.5+0.5*sin(t*(1.2+seed*4)+seed*41),3);
        float light = exp(-d*d/(size*size)) + exp(-d*d/(size*size*12))*0.08;
        float3 hue = mix(u.primary.rgb,u.secondary.rgb,seed);
        color += mix(hue,float3(1),0.45)*light*shimmer*(0.8+u.sound.z*1.4);
    }
    int satellites = u.tonal.w > 0.5 ? 2 : 3;
    for (int i=0; i<satellites; ++i) {
        float seed = random3(float3(float(i)+113,u.tonal.z,31));
        float speed = 0.25+seed*0.2;
        float direction = i == 1 ? -1 : 1;
        float phase = seed*6.2831853+t*speed*direction
                    +sin(t*(0.18+seed*0.14)+seed*12)*0.3
                    +sin(t*(0.42+seed*0.17)+seed*26)*0.1;
        float2 center = float2(cos(phase)*(0.82+seed*0.12)
                                   +sin(t*(0.33+seed*0.2)+seed*18)*0.04,
                               sin(phase)*(1.0+seed*0.12)
                                   +cos(t*(0.27+seed*0.16)+seed*27)*0.065);
        float d = length(p-center);
        float size = 0.011+seed*0.006;
        float sphere = 1-smoothstep(size*0.87,size,d);
        float depth = sqrt(max(1-d*d/(size*size),0.0));
        float highlight = exp(-length((p-center)/size-float2(-0.3,0.34))*8);
        float glow = exp(-d*d/(size*size*7))*0.09;
        float3 hue = mix(u.primary.rgb,u.secondary.rgb,seed);
        color += hue*(glow+sphere*(0.22+depth*0.48+u.sound.y*0.18));
        color += mix(hue,float3(1),0.8)*highlight*sphere*0.65;
    }
    return color;
}
fragment float4 visualWorldFragment(Raster in [[stage_in]], constant WorldUniforms &u [[buffer(0)]]) {
    if (u.viewport.w > 5.5) return float4(musicVisualizer(in.uv,u),1);
    if (u.viewport.w > 4.5) return float4(plasmaSpark(in.uv,u),1);
    if (u.viewport.w > 3.5) return float4(twilightSky(in.uv,u),1);
    if (u.viewport.w > 2.5) return float4(nightSky(in.uv,u),1);
    if (u.viewport.w > 1.5) return float4(lightGates(in.uv,u),1);
    float2 resolution = u.viewport.xy;
    float2 p = (in.uv - float2(0.5,0.43)) * resolution / min(resolution.x,resolution.y) * 2;
    p.y = -p.y;
    float t = u.viewport.z;
    float radius = 0.90; // Fixed silhouette: no audio-driven expansion or contraction.
    float r = length(p);
    float3 primary = max(u.primary.rgb, float3(0.015));
    float3 secondary = max(u.secondary.rgb, float3(0.012));
    float3 accent = mix(u.accent.rgb, float3(1), 0.2);
    float3 color = primary * 0.001;
    // Soft light extends from the same body, without an outlined circle.
    float halo = exp(-max(r-radius,0.0)*5.0) * smoothstep(radius*0.8,radius,r);
    float gradient = saturate(0.5+p.x*0.38+p.y*0.28);
    float3 surroundingLight = mix(primary,secondary,gradient);
    surroundingLight = mix(surroundingLight,u.accent.rgb,pow(gradient,4.0)*0.22);
    color += surroundingLight * halo * (0.12 + u.sound.y*0.12 + u.motion.w*0.09);
    float3 atmosphere = color;
    if (r < radius) {
        float z = sqrt(max(radius*radius-dot(p,p),0.0));
        float3 normal = float3(p,z) / radius;
        float facing = normal.z;
        float angle = t * (0.24+u.character.x*0.12) + u.layout.x;
        float3 surface = turn(float3(p,z),angle);
        float3 lightDirection = normalize(float3(-0.6,0.8,1.2));
        float diffuse = max(0.0,dot(normal,lightDirection));
        float edge = pow(1-facing,2.3);
        float texture = field(surface * 5 + float3(0,t*0.13,0));
        // Directional light, absorption and visible front/back depth establish a solid sphere.
        color += mix(primary,secondary,texture) * (0.035 + diffuse*0.14) * (0.35+facing*0.65);
        color += mix(primary,accent,diffuse) * edge * (0.08+diffuse*0.3);
        float specular = pow(max(0.0,dot(normal,normalize(lightDirection+float3(0,0,1)))),55.0);
        color += accent * specular * 0.28;
        float transmittance = 1;
        int steps = u.tonal.w > 0.5 ? 10 : 18;
        float step = 2*z / float(steps);
        float3 emission = 0;
        for (int i=0; i<steps; ++i) {
            float depth = z - (float(i)+0.5)*step;
            float3 q = turn(float3(p,depth),angle);
            float radial = length(q) / radius;
            float envelope = (1 - smoothstep(0.75,1.0,radial));
            float3 flow = q*4 + float3(t*0.09,-t*0.17,t*0.06);
            flow += float3(sin(q.y*3+t*0.32),cos(q.z*3-t*0.23),sin(q.x*3+t*0.21))*0.35;
            float density = field(flow)*0.7 + field(flow*2.1+4.7)*0.3;
            float cloud = smoothstep(0.35,0.8,density) * envelope;
            float excitation = spectrum(saturate(q.y/radius*0.5+0.5),u);
            float filament = exp(-abs(density - (0.54 + u.tonal.x*0.06))*95) * envelope;
            float3 cellPosition = q * 24 + float3(t*0.2,-t*0.3,t*0.11);
            float3 cell = floor(cellPosition);
            float seed = random3(cell);
            float3 center = float3(random3(cell+9),random3(cell+23),random3(cell+41));
            float photon = exp(-dot(fract(cellPosition)-center,fract(cellPosition)-center)*180);
            photon *= smoothstep(0.67,0.94,seed) * envelope;
            float shimmer = 0.3 + 0.7*pow(0.5+0.5*sin(t*(1+seed*3)+seed*41),3.0);
            float3 hue = mix(primary,secondary,smoothstep(0.2,0.85,density));
            float light = cloud*(0.10+u.motion.w*0.24)
                        + filament*(0.14+excitation*0.8)
                        + photon*shimmer*(2.2+u.sound.z*12+u.motion.z*3);
            emission += transmittance * (hue*light + accent*photon*shimmer*1.8) * step * 2.1;
            transmittance *= exp(-cloud*step*(1.4+u.material.x));
        }
        color += emission;
        // Softly attenuate the volume at the silhouette; retain a readable spherical boundary.
        color = mix(atmosphere, color, 1 - smoothstep(radius-0.012,radius,r));
    }
    color += sphereSatellites(p,u);
    return float4(max(color,0.0),1);
}
fragment float4 visualWorldComposite(Raster in [[stage_in]], texture2d<float> scene [[texture(0)]]) {
    constexpr sampler linearSampler(coord::normalized, address::clamp_to_edge, filter::linear);
    float2 pixel = 1.0 / float2(scene.get_width(), scene.get_height());
    float3 base = scene.sample(linearSampler, in.uv).rgb;
    float3 bloom = 0;
    for (int i = 0; i < 12; ++i) {
        float angle = float(i) * 2.399963;
        float radius = 3 + float(i) * 1.8;
        float3 tap = scene.sample(linearSampler, in.uv + float2(cos(angle),sin(angle)) * pixel * radius).rgb;
        bloom += max(tap - 0.55, 0.0) / 12;
    }
    float3 color = base + bloom * 0.65;
    color = color / (1 + color); // bounded exposure without white full-screen clipping
    return float4(pow(max(color,0.0), float3(1.0/2.2)), 1);
}
