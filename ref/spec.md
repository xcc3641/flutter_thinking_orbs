# ThinkingOrbs Specification & Mathematical Model

## 1. System Overview & Design Philosophy

ThinkingOrbs is a family of dotted, genuinely 3D loading indicators engineered specifically for artificial intelligence and agent interfaces. Originally created by Jakub Antalik ([thinking-orbs](https://github.com/Jakubantalik/thinking-orbs), MIT) and ported natively to Swift by Haplo LLC, this specification defines the mathematical models, visual choreography, and design constraints for the Flutter implementation (`flutter_thinking_orbs`).

### 1.1 Pure Monochrome Aesthetic
Modern AI interfaces frequently suffer from visual over-stimulation: rainbow gradients, spinning neon halos, and pulsating colorful rings. ThinkingOrbs rejects this in favor of quiet, disciplined minimalism:
- **Strict Grayscale Ink**: Indicators are rendered purely using grayscale ink (dots and edges).
- **Environment Harmonization**: Dots automatically adapt to the background ground—dark ink on light surfaces, light ink on dark surfaces.
- **Visual Restraint**: They sit quietly beside text, status chips, avatar hubs, and toolbars without drawing undue attention away from the primary conversational or agentic content.

### 1.2 True 3D Geometry
Unlike standard 2D loaders or flat vector spinners:
- **8 of the 9 designs** are authentic 3D spatial models operating on spherical manifolds or orbital coordinate systems.
- Coordinates undergo genuine 3D Euler rotations (yaw, pitch/tilt, roll), orthographic depth projection, depth-based radius scaling, and z-sorting.
- Shading is derived directly from projected depth coordinates ($z$), creating a tangible sense of volume, orientation, and depth.
- The 9th design (**Shaping**) operates as a closed 2D continuous polyline parameterized by arc length, providing a morphing geometric outline.

### 1.3 Synchronization & Phase Coherence
In multi-agent or complex conversational workflows, several indicators may appear simultaneously on screen (e.g., in a list of parallel tool calls, status rows, or multi-step reasoning chains).
- All orbs draw their phase from a single unified clock (`OrbClock`).
- Because every orb references identical system-relative time, all orbs on screen remain strictly in phase with one another, eliminating chaotic visual beat frequencies.

---

## 2. The 9 Designs Catalog

Every design represents a distinct operational state in an AI or autonomous agent workflow.

| Design | Mode | Semantic Meaning & Reach-For-It | Visual Effect |
|---|---|---|---|
| **Working** | `orbits` | General-purpose busy, execution, running tasks | Particles revolving on tilted orbital planes around a shared center |
| **Searching** | `globe` | Web retrieval, vector search, index lookups | A scan meridian sweep passing across a dotted latitude/longitude globe |
| **Solving** | `rubik` | Complex reasoning, mathematics, code generation | Toroidal bands scramble in discrete quarter-turns, then click back solved |
| **Listening** | `wave` | Audio capture, voice input, speech-to-text | Dual harmonic waveforms rolling through concentric latitude rings |
| **Connecting** | `web` | Tool invocation, API calls, backend synchronization | Dynamic constellation wiring itself with glowing data packets running edges |
| **Weaving** | `braid` | Orchestration, multi-step planning, synthesis | Three distinct strands plaiting over and under around a spherical hull |
| **Composing** | `ribbon` | Text generation, drafting replies, stream synthesis | An undulating multi-band sash twisting through 3D space |
| **Breathing** | `ring` | Model warm-up, idle deliberation, low-activity pause | A face-on circular ring with subtle radial breathing pulsations |
| **Shaping** | `morph` | Layout design, image editing, creative operations | Continuous outline smoothly morphing: Circle $\rightarrow$ Triangle $\rightarrow$ Square |

---

### 2.1 Working (`OrbMode.orbits`)
- **Semantic Role**: General computational activity.
- **Visual Choreography**: Multiple tilted elliptical orbits pass around a shared origin. Faint "ghost" dots trace the full orbital paths, while dense, darker particle clusters sweep along the trajectories at varied speeds and directions.
- **Mathematical Model**:
  - Global projector: Yaw $\theta_y = 0.12 t$, Tilt $\theta_t = 0.3$, Radius $R = 0.82 \cdot (size / 2)$.
  - Orbit generation: For each orbital index $orb \in [0, \text{orbitN})$:
    - Derive deterministic pseudorandom hashes:
      $$h_1 = \text{hashD}(orb, 1.7), \quad h_2 = \text{hashD}(orb, 5.2), \quad h_3 = \text{hashD}(orb, 8.9)$$
    - Orbit radius $r_o = R \cdot (0.45 + 0.52 h_1)$.
    - Normal vector on sphere:
      $$\theta = 2\pi h_1, \quad \phi = \arccos(2 h_2 - 1)$$
      $$\mathbf{n} = (\sin\phi \cos\theta, \cos\phi, \sin\phi \sin\theta)$$
    - Construct orthonormal basis $(\mathbf{u}, \mathbf{v})$ orthogonal to $\mathbf{n}$.
    - Orbital speed $\omega = (0.25 + 0.55 h_3) \cdot (\text{if } h_3 > 0.5 \text{ then } 1 \text{ else } -1)$.
  - Dot populations:
    - **Ghost path**: $\text{ghostN}$ dots at angle $\alpha = 2\pi \cdot (k / \text{ghostN})$. Ink white $= 0.72$, opacity $\alpha = \text{ghostA} \cdot (0.4 + 0.6 \cdot \text{depth})$.
    - **Particles**: $\text{particles}$ dots at angle $\alpha = t \cdot \omega + 2\pi \cdot (m / \text{particles}) + 6 h_2$. Dot radius $(r_{\text{part}} + r_{\text{partDepth}} \cdot \text{depth}) \cdot r_s$, ink white $= 0.3 - 0.22 \cdot \text{depth}$.

---

### 2.2 Searching (`OrbMode.globe`)
- **Semantic Role**: Retrieval-augmented generation (RAG), web search, vector database queries.
- **Visual Choreography**: A globe mapped with latitude rings and longitude dots rotates steadily. A high-energy vertical scan meridian sweeps around the globe, causing dots under its beam to expand in radius and brighten, producing a radar-like inspection sweep.
- **Mathematical Model**:
  - Spin rate: $\omega_{\text{spin}} = 0.5$.
  - Oscillating tilt: $\theta_t(t) = 0.4 + 0.06 \sin(0.35 t)$.
  - Projector: Yaw $\theta_y = 0.5 t$, Tilt $\theta_t(t)$, Scale $R = 0.82 \cdot (size / 2)$.
  - Scan sweep angle:
    $$\theta_{\text{scan}}(t) = t \cdot (\omega_{\text{spin}} + (1.7 - \omega_{\text{spin}}) \cdot \text{scanMul})$$
  - Surface mapping:
    - Latitude $\phi \in [-\pi/2, \pi/2]$ partitioned into $\text{latRings}$.
    - Longitude count per ring: $\text{lonCount} = \max(1, \lfloor |\cos\phi| \cdot \text{lonDensity} + 0.5 \rfloor)$.
    - Meridian proximity boost:
      $$\Delta\theta = \text{angleDelta}(\lambda + t \cdot \omega_{\text{spin}}, \theta_{\text{scan}})$$
      $$\text{boost} = \exp\left(-\frac{\Delta\theta^2}{0.18}\right) \cdot \max(0, z)$$
    - Dot radius: $r = (r_{\text{base}} + r_{\text{depth}} \cdot \text{depth} + r_{\text{boost}} \cdot \text{boost}) \cdot r_s$.
    - Opacity: $a = \text{dimBase} + (1 - \text{dimBase}) \cdot \min(1, \text{boost})$.

---

### 2.3 Solving (`OrbMode.rubik`)
- **Semantic Role**: Deep reasoning, chain-of-thought, mathematical proofs, symbolic code generation.
- **Visual Choreography**: A dotted sphere partitioned into geometric axial slices. In a rhythmic machine-like cycle, equatorial and meridian bands scramble through rapid $90^\circ$ quarter-turns, then execute an exact palindrome replay to click back into a pristine solved sphere before repeating.
- **Mathematical Model**:
  - Deterministic move schedule: $N_{\text{moves}} = 14$. For $i \in [0, N_{\text{moves}})$:
    - Axis $k \in \{0, 1, 2\}$ (X, Y, Z); slice range $[lo, hi]$ with width $0.5$.
    - Angle $\Delta\theta = \pm \pi / 2$.
  - Palindrome solve cycle:
    - Cycle period: $T_{\text{cycle}} = 2 \cdot N_{\text{moves}} \cdot t_{\text{slot}} + t_{\text{rest}}$, where $t_{\text{slot}} = 0.42\text{s}, t_{\text{rest}} = 1.2\text{s}$.
    - Ease curve (machine ease-out): $p = \text{fractional slot progress}$; $cl = \min(1, p / 0.7)$;
      $$e_p = 1 - (1 - cl)^3$$
    - Forward phase ($0 \le \text{slot} < N_{\text{moves}}$): slice rotates from $0 \rightarrow 1$.
    - Return phase ($N_{\text{moves}} \le \text{slot} < 2 N_{\text{moves}}$): slice replays backward from $1 \rightarrow 0$.
  - Active band highlighting: Dots in the currently rotating band receive active radius expansion $r_{\text{active}}$ and ink darkening ($white - 0.14$).

---

### 2.4 Listening (`OrbMode.wave`)
- **Semantic Role**: Voice input, microphone streaming, audio transcription.
- **Visual Choreography**: A sphere structured as concentric horizontal latitude rings. Dual asynchronous sinusoidal waves travel through the rings, causing undulating ripples of dot displacement, radius pulsation, and ink darkening that resemble an organic physical audio visualizer.
- **Mathematical Model**:
  - Base radius: $R = 0.874 \cdot (size / 2)$ ($0.76 \times 1.15$ compensation factor).
  - Wave synthesis per ring $r_i \in [0, \text{rings}]$:
    $$w(r_i, t) = 0.62 \sin(2.1 t - 0.52 r_i) + 0.38 \sin(1.27 t + 0.83 r_i)$$
  - Deformed radius: $R_{\text{eff}} = R \cdot (0.88 + 0.105 w)$.
  - Radial coordinates:
    $$\mathbf{p} = (R_{\text{eff}} \cos\phi \cos\lambda, R_{\text{eff}} \sin\phi, R_{\text{eff}} \cos\phi \sin\lambda)$$
  - Crest amplification: $\text{crest} = \max(0, w)$.
  - Radius scaling: $r = (r_{\text{base}} + r_{\text{depth}} \cdot \text{depth}) \cdot (1 + 0.4 \cdot \text{crest}) \cdot r_s$.
  - Ink white: $white = 0.66 - 0.56 \cdot \text{depth} - 0.1 \cdot \text{crest}$.

---

### 2.5 Connecting (`OrbMode.web`)
- **Semantic Role**: Tool calls, external API dispatch, database synchronization, distributed networking.
- **Visual Choreography**: Nodes positioned via a spherical Fibonacci lattice wander slowly under smooth 2D value noise. Proximity-based lines dynamically form between neighboring nodes. Bright high-velocity signal packets traverse edges between nodes.
- **Mathematical Model**:
  - Node placement: $\text{nodeN}$ nodes distributed via Fibonacci spiral:
    $$y_i = 1 - \frac{2i + 1}{\text{nodeN}}, \quad \text{rad}_i = \sqrt{1 - y_i^2}, \quad a_i = i \cdot \pi(3 - \sqrt{5})$$
  - Noise displacement: Perturb node vectors by Value Noise $\text{vnoise}(i \cdot c_1, 0.24 t)$ and re-normalize to unit sphere.
  - Dynamic edge generation:
    - For all pairs $(i, j)$ with $i < j$: calculate Euclidean distance $d = \|\mathbf{n}_i - \mathbf{n}_j\|$.
    - If $d < \text{thr}$ (default $0.72$): emit line segment with width $w = \max(0.6, \text{lineW} \cdot r_s)$, ink white $= 0.42$, and opacity:
      $$\alpha_{\text{line}} = \left(1 - \frac{d}{\text{thr}}\right) \cdot (0.3 + 0.55 \cdot \text{depth})$$
  - Node pulsation: $r = (r_{\text{node}} + r_{\text{depth}} \cdot \text{depth}) \cdot (1 + 0.25 \sin(1.4 t + 2.7 i)) \cdot r_s$.
  - Signal packets: $\text{signals}$ packets traveling along linear interpolations between deterministic pseudo-randomly selected node pairs $(A, B)$ using $\text{frac}(0.55 t + 7.31 s)$. Ink is intense dark ($white = 0.05$).

---

### 2.6 Weaving (`OrbMode.braid`)
- **Semantic Role**: Autonomous workflows, task breakdown, complex multi-agent orchestration.
- **Visual Choreography**: A spherical lattice hull encircled by three distinct sinusoidal ribbon strands that plait over and under each other in continuous helical precession.
- **Mathematical Model**:
  - Ghost hull: $\text{ghostN} = 150$ stationary reference dots distributed on sphere surface.
  - Three strands: Index $s \in \{0, 1, 2\}$, with angular phase $\phi_s = \frac{2\pi s}{3}$.
  - Strand coordinates along parameter $u \in [-0.96, 0.96]$:
    $$u = \left(\text{frac}\left(\frac{i}{\text{strandN}} + 0.045 t\right) \cdot 2 - 1\right) \cdot 0.96$$
    $$\text{surf} = \sqrt{\max(0, 1 - u^2)}$$
    $$\theta = u \cdot \pi \cdot \text{turns} + \phi_s$$
  - Radial braid undulation (the over-under plait):
    $$\text{weave} = 1 + 0.075 \sin(2\pi \cdot \text{turns} \cdot u + 2\phi_s + 0.8 t)$$
    $$R_{\text{eff}} = \text{surf} \cdot R \cdot \text{weave}, \quad Y_{\text{eff}} = u \cdot R \cdot \text{weave}$$
  - Pole fade: $\alpha_{\text{end}} = \min(1, (1 - |u|) / 0.1)$.

---

### 2.7 Composing (`OrbMode.ribbon`)
- **Semantic Role**: LLM completion, token streaming, prose writing, code output.
- **Visual Choreography**: A multi-lane sash or ribbon twisting and tumbling through 3D space with continuous traveling sine waves rippling down its lanes.
- **Mathematical Model**:
  - Coordinate system: Band plane precesses with yaw $\theta_y = 0.24 t \cdot \text{spin}$ and tilt $\theta_t = 0.55 + 0.3 \sin(0.18 t) \cdot \text{spin}$.
  - Plane orthonormal basis: $(\mathbf{u}, \mathbf{v})$ with normal $\mathbf{n} = \mathbf{u} \times \mathbf{v}$.
  - Multi-lane distribution: $\text{lanes} = \lfloor \text{baseLanes} \cdot \text{bandMul} + 0.5 \rfloor$.
  - Dual traveling wave wobble: For lane index $w$ and segment $k$:
    $$\text{wob} = (0.16 \sin(3\alpha - 1.7 t + 0.22 w) + 0.07 \sin(5\alpha + 1.1 t)) \cdot \text{wobMul}$$
  - Ribbon displacement: Offset along plane normal $\mathbf{n}$ by $\text{laneOff} + \text{wob}$, then projected and normalized onto sphere radius.
  - Edge shading: Lateral lanes darken toward the edges ($white \propto \text{edge}$), providing ribbon contour definition.

---

### 2.8 Breathing (`OrbMode.ring`)
- **Semantic Role**: Idle reflection, model waiting, standby state.
- **Visual Choreography**: A clean, face-on circular multi-lane ring facing directly toward the camera, executing slow, calming radial breathing oscillations without 3D tumbling.
- **Mathematical Model**:
  - Derived from `OrbMode.ribbon` with special constraints:
    - $\text{faceOn} = 1$: Cancels camera tilt ($\theta_t = -\text{camTilt} = -0.3$) so the ring projects as a true circle rather than an ellipse.
    - $\text{spin} = 0$: Eliminates 3D tumble precession.
    - $\text{ghostN} = 0$: Removes background spherical dots completely.
    - Wobble modulation shifts from out-of-plane normal displacement to in-plane radial modulation:
      $$\text{radial} = 1 + \text{wob}, \quad \text{off} = \text{laneOff}$$
  - Radial compensation: Base radius $R_{\text{base}} = R / (1 + 0.85 \cdot \text{wobAmp})$ ensures expanding lobes remain within bounding bounds.

---

### 2.9 Shaping (`OrbMode.morph`)
- **Semantic Role**: Graphic design, image synthesis, spatial layout, canvas transformation.
- **Visual Choreography**: A single flat 2D closed polygon outline whose dots smoothly transition between Circle, Equilateral Triangle, and Square, holding briefly at each shape.
- **Mathematical Model**:
  - Polyline definition:
    - **Circle** ($k=0$): $\mathbf{p}(\theta) = (0.24 \cos\theta, 0.24 \sin\theta)$ starting at top-center ($\theta = -\pi/2$).
    - **Triangle** ($k=1$): Vertices $(0, -0.26) \rightarrow (0.24, 0.16) \rightarrow (-0.24, 0.16)$.
    - **Square** ($k=2$): 5-vertex walk starting at top-center: $(0, -0.2) \rightarrow (0.2, -0.2) \rightarrow (0.2, 0.2) \rightarrow (-0.2, 0.2) \rightarrow (-0.2, -0.2)$.
  - Morph cycle timing:
    - Hold duration: $t_{\text{hold}} = 1.4\text{s}$, Transition duration: $t_{\text{morph}} = 0.9\text{s}$.
    - Segment duration: $t_{\text{seg}} = 2.3\text{s}$. Full cycle for 3 shapes: $6.9\text{s}$.
    - Hermite smoothstep blend parameter:
      $$x = \frac{t_{\text{local}} - t_{\text{hold}}}{t_{\text{morph}}}, \quad m = x^2 (3 - 2x)$$
  - Arc-length parameterization:
    - 160 sample points measure the perimeter of the blended path to compute cumulative lengths.
    - $N$ dots are placed at strictly equal arc-length intervals along the blended outline, preventing dot bunching at corners during morph transitions.
  - Micro-pulse: Dots pulsate gently during shape holds: $\text{pulse} = 1 + 0.02 \sin(3.1 t_{\text{local}})$.

---

## 3. Parameter Tunings Table

Every design configuration is resolved from a base profile multiplied by preset scale factors.

### 3.1 Base ("Fine") Profiles
```
globe:   latRings=17, lonDensity=44, rBase=0.6, rDepth=1.7, rBoost=1.0, inkFar=0.62, inkSpan=0.54, rsPow=0.6, rMin=0.3
orbits:  orbitN=12, ghostN=40, ghostR=0.9, ghostA=0.5, particles=3, partR=1.2, partRDepth=1.6, rsPow=0.6, rMin=0.3
rubik:   latRings=15, lonDensity=40, moveCount=14, rBase=0.6, rDepth=1.7, rActive=0.3, inkFar=0.62, inkSpan=0.54, rsPow=0.6, rMin=0.3
wave:    rings=15, lonDensity=40, rBase=0.6, rDepth=1.7, rsPow=0.6, rMin=0.3
web:     nodeN=30, thr=0.72, signals=5, nodeR=1.4, nodeRDepth=1.8, lineW=0.8, rsPow=0.6, rMin=0.3
braid:   strandN=52, turns=3.0, ghostN=150, rBase=1.2, rDepth=1.8, rsPow=0.6, rMin=0.3
ribbon:  lanes=5, segs=88, ghostN=150, rBase=1.1, rDepth=1.7, rsPow=0.6, rMin=0.3
ring:    lanes=5, segs=88, ghostN=0, faceOn=1, rBase=1.1, rDepth=1.7, rsPow=0.6, rMin=0.3
morph:   rDot=0.021, iconD=1, rMin=0.25
```

### 3.2 Tuned Presets Matrix

| Design | Size | Speed | Count Mult | Size Mult | Extra Custom Options |
|---|---|---|---|---|---|
| **working** (`orbits`) | Regular (64) | 1.885 | 1.000 | 1.000 | — |
| | Small (20) | 3.900 | 0.238 | 2.400 | — |
| **searching** (`globe`) | Regular (64) | 2.015 | 0.420 | 1.150 | `scanMul: 4.08, dimBase: 0.45` |
| | Small (20) | 2.665 | 0.105 | 1.750 | `scanMul: 4.335, dimBase: 0.45` |
| **solving** (`rubik`) | Regular (64) | 1.820 | 0.350 | 1.050 | — |
| | Small (20) | 1.950 | 0.088 | 1.900 | — |
| **listening** (`wave`) | Regular (64) | 4.388 | 0.341 | 1.000 | — |
| | Small (20) | 3.998 | 0.105 | 1.600 | — |
| **connecting** (`web`) | Regular (64) | 3.315 | 1.350 | 0.950 | — |
| | Small (20) | 6.630 | 0.250 | 1.520 | — |
| **weaving** (`braid`) | Regular (64) | 1.625 | 0.500 | 1.000 | — |
| | Small (20) | 2.750 | 0.1125 | 1.360 | — |
| **composing** (`ribbon`) | Regular (64) | 2.340 | 0.250 | 0.850 | `spin: 0, bandMul: 3.9, wobMul: 1` |
| | Small (20) | 3.120 | 0.051 | 1.073 | `spin: 0, bandMul: 4.94, wobMul: 1` |
| **breathing** (`ring`) | Regular (64) | 3.240 | 0.250 | 0.956 | `spin: 0, bandMul: 3.627, wobMul: 0.368` |
| | Small (20) | 3.780 | 0.028 | 1.622 | `spin: 0, bandMul: 3.968, wobMul: 0.565` |
| **shaping** (`morph`) | Regular (64) | 2.405 | 0.702 | 0.395 | `spread: 1.45` |
| | Small (20) | 2.080 | 0.530 | 1.011 | `spread: 1.45` |

---

## 4. The 2 Purpose-Tuned Sizes

ThinkingOrbs provides two canonical sizes:
1. **Regular (`OrbSize.regular`, 64 pt)**: Primary avatars, hero cards, empty states, and standalone thinking screens.
2. **Small (`OrbSize.small`, 20 pt)**: Inline text status chips, toolbars, buttons, and list rows.

### 4.1 Why They Are Separate Designs (Not Scaled Bitmaps)
Uniformly downscaling a 64 pt orb to 20 pt produces an illegible, muddy smudge:
- 500+ dots packed into a 20 pt box overlap and turn into solid black noise.
- Sub-pixel anti-aliasing washes out high-frequency dot patterns.
- Conversely, scaling up a 20 pt design to 64 pt results in sparse, giant dots that lose all 3D spherical fidelity.

Therefore, `regular` and `small` are **distinct architectural tunings**:

### 4.2 Non-Linear 2D Lattice Scaling ($\sqrt{\text{scale}}$)
For 2D dot arrays (e.g., latitude $\times$ longitude, rings $\times$ density, lanes $\times$ segments), applying linear scaling to both dimensions would scale the total dot count quadratically ($O(s^2)$).
- Count pairs: `(latRings, lonDensity)`, `(rings, lonDensity)`, `(lanes, segs)`.
- Each individual dimension is scaled by the square root:
  $$\text{dim}' = \max(2, \text{jsRound}(\text{dim} \cdot \sqrt{\text{scale}}))$$
- This guarantees the **total dot count** scales strictly linearly by $\text{scale}$.

### 4.3 Sub-Linear Radius Scaling ($r_{\text{scale}}$)
Dot radii were originally balanced for a 300 pt reference box. To preserve visibility on compact displays:
$$r_s = \left(\frac{\text{size}}{300}\right)^p, \quad \text{where } p = \text{rsPow} \approx 0.6$$
Since $p < 1.0$, dots shrink more slowly than the bounding box, retaining distinct physical presence at 20 pt.

### 4.4 Tuned Speeds
At 20 pt, a particle traveling at the same angular velocity traverses far fewer physical screen pixels per second, reading as slow or stalled. Small presets increase orbital and spin speeds (e.g., Working speed increases from $1.885 \rightarrow 3.9$, Connecting increases from $3.315 \rightarrow 6.63$) to preserve perceptual energy.

---

## 5. Shimmer Specification

The `ThinkingOrbLabel` and `thinkingShimmer` modifier create a distinctive shimmering text highlight that signals ongoing agent activity.

```
                  ◄────────────── 0.8 × w ──────────────►
[   DIM TEXT    ] [  CLEAR ──► FULL WHITE ──► CLEAR     ] [   DIM TEXT    ]
                  ◄────────────── Left-to-Right ────────►
```

### 5.1 Geometry & Timing
- **Cycle Duration**: Exactly 2.0 seconds per sweep ($T_{\text{shimmer}} = 2.0\text{s}$).
- **Phase Function**: Linear progression $q \in [0, 1)$:
  $$q = \frac{t}{2.0} - \left\lfloor \frac{t}{2.0} \right\rfloor$$
- **Highlight Band Width**: $0.8 \times \text{width of content}$ ($w_{\text{band}} = 0.8 w$).
- **Horizontal Position**:
  $$\text{offset}_x(q) = -w + 3w \cdot q - 0.4w$$
  This causes the band to sweep cleanly from entirely off-screen left to entirely off-screen right.

### 5.2 Opacity & Gradients
- **Base Content Dimming**: The content underneath acts as a subdued backdrop:
  - Light Ground: Base opacity = **0.45**
  - Dark Ground: Base opacity = **0.50**
- **Highlight Band**: Overlaid using a linear gradient mask:
  - Gradient Stops: `[Color.transparent, Color.white, Color.transparent]`
  - Blending: Content rendered at full opacity (**1.0**) inside the moving band mask.

### 5.3 Accessibility Overrides
- **Reduce Motion (`disableAnimations`)**: The moving shimmer band is disabled; base text remains stationary at full opacity (**1.0**).
- **Increase Contrast (`highContrast`)**: Base text is rendered at full opacity (**1.0**) to guarantee WCAG compliance.

---

## 6. Ink & Grayscale Quantization

### 6.1 256 Quantization Levels (8-bit)
To match HTML5 Canvas `rgba(...)` string evaluation and prevent per-frame memory allocations:
- Ink luminance is quantized into 256 discrete levels: $k \in [0, 255]$.
- Precomputed palette lookup table:
  $$\text{palette}[k] = \text{Color.fromARGB}(255, k, k, k)$$

### 6.2 Light vs. Dark Theme Inversion
In mathematical formulations, `white` denotes ink on paper:
- $white = 0.0 \implies \text{black / maximum ink}$
- $white = 1.0 \implies \text{white / no ink}$

When rendering:
- **Light Ground (`Brightness.light`)**:
  $$k = \left\lfloor \min(1, \max(0, white)) \cdot 255 + 0.5 \right\rfloor$$
  Near dots ($z > 0$) have lower $white$ values and render as dense black ink against light paper.
- **Dark Ground (`Brightness.dark`)**:
  $$k = \left\lfloor \min(1, \max(0, 1.0 - white)) \cdot 255 + 0.5 \right\rfloor$$
  The formula is mirrored: near dots have high $1.0 - white$ values and render as bright white dots against the dark background.
- **Alpha Separation**: Alpha ($a \in [0, 1]$) is applied directly to the painting context or paint opacity, preserving the 256 pre-quantized ink palette.
