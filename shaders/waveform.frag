/* waveform.frag - smooth single-line renderer (continuous + overview) */

extern Image SampTex;      /* R32F  one texel per mono sample  */
extern Image ColTex;       /* RGBA32F one texel per FFT window */

uniform int   u_sampleCount;
uniform int   u_winCount;
uniform int   u_sampW;
uniform int   u_sampH;
uniform int   u_winW;
uniform int   u_winH;

uniform float u_offset;
uniform float u_samplesPerPixel;  /* zoom               */
uniform float u_centerY;
uniform float u_gain;             /* vertical scale     */
uniform float u_baseThickness;    /* stroke radius, px  */
uniform float u_hop;              /* hop size           */

/* helpers */
ivec2 tileXY(int i, int w) {
  return ivec2(
    i - (i / w) * w,
    i / w
  );
}

float fetchSample(int idx) {
  idx = clamp(idx, 0, u_sampleCount - 1);
  ivec2 c = tileXY(idx, u_sampW);
  return Texel(
    SampTex,
    vec2(
      (float(c.x) + 0.5) / float(u_sampW),
      (float(c.y) + 0.5) / float(u_sampH)
    )
  ).r;
}

vec4 fetchWindow(int idx) {
  idx = clamp(idx, 0, u_winCount - 1);
  ivec2 c = tileXY(idx, u_winW);
  return Texel(
    ColTex,
    vec2(
      (float(c.x) + 0.5) / float(u_winW),
      (float(c.y) + 0.5) / float(u_winH)
    )
  );
}

/* signed distance from point P to segment AB */
float sdSegment(vec2 P, vec2 A, vec2 B) {
  vec2 PA = P - A;
  vec2 BA = B - A;
  float t = clamp(
    dot(PA, BA) / dot(BA, BA),
    0.0,
    1.0
  );
  return length(PA - BA * t);
}

/* main effect */
vec4 effect(vec4 v, Image dummy, vec2 uv, vec2 pc) {
  /* world-x expressed in samples */
  float sampleF = u_offset + pc.x * u_samplesPerPixel;

  /* A. high zoom (≤ 1 sample / pixel) */
  if (u_samplesPerPixel <= 1.0) {
    int   s0   = int(floor(sampleF));
    int   s1   = s0 + 1;
    float frac = fract(sampleF);

    float a0 = fetchSample(s0) * u_gain;
    float a1 = fetchSample(s1) * u_gain;

    vec2 A = vec2(0.0, u_centerY - a0);
    vec2 B = vec2(1.0, u_centerY - a1);
    vec2 P = vec2(frac, pc.y);

    float dist  = sdSegment(P, A, B);
    float alpha = clamp(u_baseThickness - dist, 0.0, 1.0);

    float winIdxF = sampleF / u_hop;
    int   w0      = int(floor(winIdxF));
    int   w1      = w0 + 1;
    float fw      = fract(winIdxF);

    vec3 col = mix(
      fetchWindow(w0).rgb,
      fetchWindow(w1).rgb,
      fw
    );

    return vec4(col * alpha, alpha);
  }

  /* B. low zoom (> 1 sample / pixel) */
  float winIdxF = sampleF / u_hop;
  int   w0      = int(floor(winIdxF));
  int   w1      = w0 + 1;
  float fw      = fract(winIdxF);

  vec4 W0 = fetchWindow(w0);
  vec4 W1 = fetchWindow(w1);

  float peak = mix(W0.a, W1.a, fw) * u_gain;
  vec3  col  = mix(W0.rgb, W1.rgb, fw);

  float dist  = abs(pc.y - u_centerY) - peak;
  float alpha = clamp(u_baseThickness - dist, 0.0, 1.0);

  return vec4(col * alpha, alpha);
}
