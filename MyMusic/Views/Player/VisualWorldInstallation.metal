#include <metal_stdlib>
using namespace metal;

struct WorldUniforms {
    float4 viewport, motion, sound, character, tonal;
    float4 primary, secondary, accent;
    float4 material, layout, spatial;
    float4 band0, band1, band2, band3, band4, band5;
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
    int i = clamp(int(p * 23), 0, 23);
    float4 bands[6] = {u.band0,u.band1,u.band2,u.band3,u.band4,u.band5};
    return bands[i/4][i%4];
}
// Blue Cosmos: stable star identities, slow bounded drift at three depths, and diffuse nebula.
float3 nightSky(float2 uv, constant WorldUniforms &u) {
    float aspect = u.viewport.x / u.viewport.y;
    float2 p = (uv - 0.5) * float2(aspect, 1);
    float t = u.viewport.z;
    float2 drift = float2(t * 0.0017, sin(t * 0.04) * 0.007);
    float3 blue = float3(0.055, 0.18, 0.65);
    float3 tint = mix(blue, mix(u.primary.rgb,u.secondary.rgb,0.5), 0.32);
    float cloud = field(float3(p * 4 + drift, 7.2));
    float detail = field(float3(p * 10 - drift, 13.1));
    float lane = exp(-pow((p.x + p.y * 0.46 + (cloud-0.5)*0.24) * 4.5, 2));
    float haze = lane * pow(cloud * 0.7 + detail * 0.3, 2.2);
    float3 color = float3(0.0006,0.0012,0.004);
    color += tint * haze * (0.09 + u.motion.w * 0.035);
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
            if (seed < 0.73 + depth * 0.045) continue;
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
                light = (0.08+1.5*pow(0.5+0.5*sin(t*(1.8+seed*2)+random3(key+191)*6.283),2.0))*(0.8+response*0.5);
            } else if (behavior >= 0.8) {
                light = 0.06+pulse*(2.6+response*1.5);
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
            float power = (0.28+depth*0.22)*light;
            color += starlight*(core+halo)*power*2.1;
        }
    }
    return color;
}
float tubeDistance(float2 p, float2 a, float2 b) {
    float2 ab = b-a;
    return length(p-a-ab*clamp(dot(p-a,ab)/max(dot(ab,ab),0.00001),0.0,1.0));
}
// Pulse Neon: fluorescent X-braces pass the viewer, with a clear central passage.
float3 lightGates(float2 uv, constant WorldUniforms &u) {
    float2 p = (uv-float2(0.5,0.43))*u.viewport.xy/min(u.viewport.x,u.viewport.y)*2;
    p.y = -p.y;
    float3 primary = max(u.primary.rgb,float3(0.015));
    float3 secondary = max(u.secondary.rgb,float3(0.015));
    float3 color = primary*0.002;
    float travel = u.viewport.z * 0.32;
    int count = u.tonal.w > 0.5 ? 6 : 10;
    for (int i=0; i<count; ++i) {
        float depth = fract((float(i)+0.5)/float(count)-travel);
        float scale = 1.0/(0.3+depth*9);
        float fade = smoothstep(0.0,0.07,depth)*(1-smoothstep(0.84,1.0,depth));
        float2 q = p/scale;
        float distance = 100;
        for (int side=-1; side<=1; side+=2) {
            float x = float(side);
            distance = min(distance,tubeDistance(q,float2(x*0.85,-1.1),float2(x*1.4,1.1)));
            distance = min(distance,tubeDistance(q,float2(x*1.4,-1.1),float2(x*0.85,1.1)));
        }
        distance = min(distance,tubeDistance(q,float2(-1.4,1.1),float2(1.4,1.1)));
        distance = min(distance,tubeDistance(q,float2(-1.4,-1.1),float2(1.4,-1.1)));
        float width = max(0.008,1.1/(u.viewport.y*scale));
        float core = exp(-pow(distance/width,2));
        float glow = exp(-distance/0.055)*0.3 + exp(-distance/0.2)*0.055;
        float3 hue = mix(primary,secondary,0.5+0.5*sin(depth*4+q.y*0.8));
        float excitation = 0.8+spectrum(depth,u)*0.75;
        color += (hue*glow*4 + mix(hue,float3(1),0.72)*core*2)*fade*excitation;
    }
    // Dim converging road light describes forward travel without covering the opening.
    float horizonGlow = exp(-length(p)*3.5);
    color += mix(primary,secondary,0.5)*horizonGlow*(0.025+u.motion.w*0.035);
    return color;
}
fragment float4 visualWorldFragment(Raster in [[stage_in]], constant WorldUniforms &u [[buffer(0)]]) {
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
    color += surroundingLight * halo * (0.17 + u.sound.y*0.035);
    float3 atmosphere = color;
    if (r < radius) {
        float z = sqrt(max(radius*radius-dot(p,p),0.0));
        float3 normal = float3(p,z) / radius;
        float facing = normal.z;
        float angle = t * 0.3 + u.layout.x;
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
            float light = cloud*(0.12+u.motion.w*0.18)
                        + filament*(0.18+excitation*0.8)
                        + photon*shimmer*(3+u.sound.z*10);
            emission += transmittance * (hue*light + accent*photon*shimmer*1.8) * step * 2.1;
            transmittance *= exp(-cloud*step*(1.4+u.material.x));
        }
        color += emission;
        // Softly attenuate the volume at the silhouette; retain a readable spherical boundary.
        color = mix(atmosphere, color, 1 - smoothstep(radius-0.012,radius,r));
    }
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
