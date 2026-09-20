#include <metal_stdlib>
using namespace metal;

struct WorldUniforms {
    float4 viewport, motion, sound, character, tonal;
    float4 primary, secondary, accent;
    float4 material, layout, spatial, burst;
    float4 plasma0, plasma1, plasma2, plasma3, plasma4;
    float4 plasmaBranch0, plasmaBranch1, plasmaBranch2, plasmaBranch3, plasmaBranch4;
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
// The nine main vertices and two short forks come from 24 authored silhouettes.
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
    float width = kind == 0 ? 0.0015 : kind == 1 ? 0.0011 : 0.00075;
    float d2 = distance*distance;
    float aura = exp(-d2/0.0008);
    float ion = exp(-d2/(width*width*18.0));
    float core = exp(-d2/(width*width));
    color += hue*(aura*0.035+ion*0.55)*light;
    color += float3(1,0.97,1)*core*2.7*light;
    // The air only catches light during the initial flash.
    color += hue*exp(-dot(p-nearest,p-nearest)/0.026)*light*0.018;
    if (kind == 0) color += hue*exp(-dot(p-points[4]*float2(aspect,1),p-points[4]*float2(aspect,1))/0.1)*strength*exp(-age*35)*0.075;
    if (age < 0.25) {
        float2 forks[10] = {u.plasmaBranch0.xy,u.plasmaBranch0.zw,
                           u.plasmaBranch1.xy,u.plasmaBranch1.zw,
                           u.plasmaBranch2.xy,u.plasmaBranch2.zw,
                           u.plasmaBranch3.xy,u.plasmaBranch3.zw,
                           u.plasmaBranch4.xy,u.plasmaBranch4.zw};
        for (int branchIndex=0; branchIndex<2; ++branchIndex) {
            float response = branchIndex == 0 ? strength : max(max(mid,treble),strength*0.55);
            if (response < 0.12) continue;
            float branchDistance = 2;
            for (int segment=0; segment<4; ++segment) {
                float2 a = forks[branchIndex*5+segment]*float2(aspect,1);
                float2 b = forks[branchIndex*5+segment+1]*float2(aspect,1);
                float2 delta = b-a;
                float t = saturate(dot(p-a,delta)/max(dot(delta,delta),0.000001));
                branchDistance = min(branchDistance,length(p-a-delta*t));
            }
            float branchLight = response*exp(-age*10.0)*smoothstep(0.026,0.07,age);
            float bd2 = branchDistance*branchDistance;
            float3 branchHue = branchIndex == 0 ? cyan : rose;
            color += branchHue*exp(-bd2/0.000018)*branchLight*0.55;
            color += float3(1)*exp(-bd2/0.0000007)*branchLight*1.1;
        }
    }
    // Photon Sphere's small colored halo and white core, carried close to the
    // discharge. Only every fourth charge breaks away as a fast spark.
    int charges = u.tonal.w > 0.5 ? 7 : 12;
    for (int i=0; i<charges; ++i) {
        float key = float(i)+u.spatial.z*11;
        int pointIndex = 1+(i*5)%7;
        if (float(pointIndex)/8.0 > progress+0.1) continue;
        float seed = random3(float3(key,u.tonal.z,73));
        float2 tangent = normalize((points[pointIndex+1]-points[pointIndex-1])*float2(aspect,1));
        float2 normal = float2(-tangent.y,tangent.x);
        float2 point = points[pointIndex]*float2(aspect,1)
                     +normal*(seed-0.5)*0.035;
        float phase = seed*6.2831853+age*(9.0+seed*7.0);
        point += float2(cos(phase),sin(phase))*(0.005+seed*0.008);
        bool flying = i%4 == 0;
        if (flying) point += float2(random3(float3(key,7,3))-0.5,
                                     random3(float3(key,17,9))-0.5)*age*0.40;
        float d2 = dot(p-point,p-point);
        float shimmer = 0.25+0.75*pow(0.5+0.5*sin(age*(12.0+seed*8.0)+seed*41.0),3.0);
        float sparkLight = strength*exp(-age*(flying ? 14.0 : 18.0))*shimmer;
        float radius = 0.0012+seed*0.0018;
        float3 tint = mix(violet,cyan,seed);
        if (i%5 == 0) tint = rose;
        color += tint*exp(-d2/(radius*radius*14.0))*sparkLight*0.12;
        color += mix(tint,float3(1),0.62)*exp(-d2/(radius*radius))*sparkLight*0.88;
    }
    return max(color,0.0);
}
// The same microphoton layer used by Photon Sphere surrounds the visualizer.
float3 spherePhotons(float2 p, constant WorldUniforms &u);

float3 musicVisualizer(float2 uv, constant WorldUniforms &u) {
    float bass = saturate(u.sound.x);
    float mid = saturate(u.sound.y);
    float high = saturate(u.sound.z);
    float t = u.viewport.z*4.0;
    float position = saturate(uv.x)*47.0;
    int index = clamp(int(position),0,46);
    float fraction = smoothstep(0.0,1.0,fract(position));
    float sample = mix(waveformSample(index,u),waveformSample(index+1,u),fraction);
    // Low notes move the line broadly, mids add a smaller undulation, and
    // highs give its edge a fine tremor. This remains one continuous trace.
    float waveY = 0.5 + sample*0.075
                + bass*0.068*sin(uv.x*12.566-t*0.8)
                + mid*0.027*sin(uv.x*43.982-t*1.35)
                + high*0.010*sin(uv.x*119.38-t*2.0);
    float d = abs(uv.y-waveY);
    float3 cyan = max(u.primary.rgb,float3(0.025));
    float3 violet = max(u.secondary.rgb,float3(0.025));
    float3 rose = max(u.accent.rgb,float3(0.025));
    float3 hue = (cyan*(0.15+bass)+violet*(0.15+mid)+rose*(0.1+high))
                 /(0.4+bass+mid+high);
    float light = 0.35+0.75*max(bass,max(mid,high));
    float3 color = float3(0.0005,0.001,0.004);
    color += hue*exp(-d*d/0.00050)*0.12*light;
    color += hue*exp(-d*d/0.000035)*0.44*light;
    color += mix(hue,float3(1),0.86)*exp(-d*d/0.0000025)*1.6*light;

    float age = u.burst.x;
    if (age < 0.8) {
        float power = max(u.burst.y,max(u.burst.z,u.burst.w));
        float2 delta = (uv-float2(0.5,0.5))*u.viewport.xy/u.viewport.y;
        float radius = 0.02+age*(u.burst.y >= u.burst.z && u.burst.y >= u.burst.w ? 0.56 : 0.43);
        float ring = exp(-pow((length(delta)-radius)/0.012,2.0));
        color += hue*ring*power*pow(1.0-age/0.8,2.0)*0.28;
    }
    float2 p = (uv-float2(0.5,0.5))*u.viewport.xy/min(u.viewport.x,u.viewport.y)*2.0;
    p.y = -p.y;
    color += spherePhotons(p,u);
    return max(color,0.0);
}
// Stable per-track seeds vary each orbit's phase, speed and wobble without frame-to-frame jumps.
float3 spherePhotons(float2 p, constant WorldUniforms &u) {
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
    return color;
}
float3 sphereSatellites(float2 p, constant WorldUniforms &u) {
    float t = u.viewport.z;
    float r = length(p);
    float3 color = spherePhotons(p,u);
    if (r < 0.72 || r > 1.38) return color;
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
