# ThinkingOrbs Verification & Testing Specification

This document defines the mathematical verification standards, test datasets, depth-tie matching algorithms, and differential sweep testing architecture required to prove 100% numerical and visual parity between `flutter_thinking_orbs` and the reference engines (TypeScript upstream and Swift native port).

---

## 1. Golden Test Dataset Specification (`orbs-golden.json`)

The authoritative golden reference file is located at:
`test/resources/orbs-golden.json`

This file was generated directly from Jakub Antalik's reference web engine (`thinking-orbs` via `npm run spec`). It bakes the exact floating-point outputs produced by the canonical TypeScript engine under Node.js / V8.

### 1.1 JSON Schema
```json
{
  "tolerance": 0.0001,
  "resolved": {
    "working-64": {
      "mode": "orbits",
      "speed": 1.885,
      "opts": {
        "orbitN": 12.0,
        "ghostN": 40.0,
        "particles": 3.0,
        ...
      }
    },
    ... (18 total resolved presets)
  },
  "cases": [
    {
      "key": "working-64-0.6",
      "state": "working",
      "size": 64,
      "t": 0.6,
      "dotCount": 516,
      "lineCount": 0,
      "dots": [ ... ],
      "lines": [ ... ]
    },
    ... (72 total test cases)
  ]
}
```

### 1.2 Preset Verification (18 Presets)
Before evaluating any geometry, the preset resolution engine must be validated:
- **Keys**: All 18 combinations: 9 designs (`working` through `shaping`) $\times$ 2 sizes (`20`, `64`).
- **Mode Matching**: String representation must match exactly.
- **Speed Matching**: Floating-point equality to within $1 \times 10^{-12}$.
- **Option Keys**: Set of resolved option keys must match the golden keys exactly.
- **Option Values**: Every option parameter must match the golden value to within $1 \times 10^{-12}$.

---

## 2. 72 Test Cases Breakdown

The test suite evaluates exactly **72 frozen frames**:
$$9 \text{ designs} \times 2 \text{ sizes (20, 64)} \times 4 \text{ timestamps} = 72 \text{ test cases}$$

### 2.1 The 4 Frozen Timestamps

| Timestamp | Dynamic Stage Tested | Key Verification Mechanics |
|---|---|---|
| **$t = 0.6\text{s}$** | Early transient & Reduce Motion anchor | Matches the static frame displayed under `accessibilityReduceMotion`. Verifies initial orbit setups and base shape formation. |
| **$t = 1.7\text{s}$** | Mid-cycle dynamics | Hits the initial scramble/solve phase in `solving`, high-energy wave ripples in `listening`, and active scan sweeps in `searching`. |
| **$t = 3.3\text{s}$** | Multi-cycle transition & packet motion | Verifies network packet hops in `connecting`, strand plaiting phase crossings in `weaving`, and Circle $\rightarrow$ Triangle transition in `shaping`. |
| **$t = 5.1\text{s}$** | Long-running phase drift | Tests accumulator stability, floating-point drift, palindrome solve returns in `solving`, and Triangle $\rightarrow$ Square transition in `shaping`. |

### 2.2 Numerical Tolerance
- **Tolerance**: $\epsilon = 0.0001$ ($1 \times 10^{-4}$ pt).
- All coordinate outputs ($x, y, z$), radii ($r$), ink luminance ($white$), and opacities ($a$) must agree with the golden vector within $\epsilon$.

---

## 3. Memory Stride & Flat Data Layout

To maintain compact JSON storage and high-throughput serialization, `orbs-golden.json` stores geometry in flat 1D numeric arrays.

### 3.1 Dot Stride 6
Each dot is encoded as a consecutive 6-element tuple:
$$\text{Dot}_i = \big[\, x, \; y, \; z, \; r, \; white, \; a \,\big]$$

```
Index:  0    1    2    3      4       5       6    7    8    9      10      11
Data: [ x₀,  y₀,  z₀,  r₀, white₀,   a₀,     x₁,  y₁,  z₁,  r₁, white₁,   a₁ ... ]
        ◄────────── Stride 6 ──────────►     ◄────────── Stride 6 ──────────►
```

- **`x`** (Double): Horizontal point position in canvas space ($[0, size]$).
- **`y`** (Double): Vertical point position in canvas space ($[0, size]$).
- **`z`** (Double): Projected depth coordinate. Larger values are closer to the camera.
- **`r`** (Double): Dot radius in points, clamped to `rMin`.
- **`white`** (Double): Ink luminance on paper ($0.0 = \text{black}$, $1.0 = \text{white}$).
- **`a`** (Double): Alpha opacity ($[0.0, 1.0]$). Clamped to $\ge 0.02$.

Total array length for a case with $N$ dots:
$$\text{length}(\text{dots}) = N \times 6$$

### 3.2 Line Stride 7
Each line segment (present in `connecting`) is encoded as a consecutive 7-element tuple:
$$\text{Line}_i = \big[\, x_1, \; y_1, \; x_2, \; y_2, \; white, \; a, \; w \,\big]$$

- **`x1, y1`** (Double): Line start point.
- **`x2, y2`** (Double): Line end point.
- **`white`** (Double): Ink luminance ($0.42$).
- **`a`** (Double): Edge opacity based on Euclidean proximity and depth.
- **`w`** (Double): Stroke width in points ($w \ge 0.6$).

Total array length for a case with $M$ lines:
$$\text{length}(\text{lines}) = M \times 7$$

---

## 4. Draw Order & Depth-Tie Matching Algorithm

### 4.1 Far-to-Near Draw Order
In ThinkingOrbs, dots are pre-sorted into strict array draw order:
- Dots are sorted by increasing $z$ (far $\rightarrow$ near).
- Painters render dots in the exact order of the array without performing secondary sorting or depth buffering.

### 4.2 The Depth-Tie Phenomenon
In floating-point environments, depth ties occur naturally:
- In **Breathing** (`ring`), `faceOn = 1` aligns the ring directly parallel to the camera projection plane ($XY$).
- Consequently, an entire concentric circular lane of dozens of dots shares an identical depth:
  $$z \approx 0.0$$
- JavaScript's V8 engine, Darwin's C `libm`, and the Dart VM compile trigonometric expressions with minor discrepancies in the least significant unit in the last place (ULP, $\approx 10^{-16}$).
- When a stable sort compares two dots where $z_A = 1.0000000000000002$ and $z_B = 1.0000000000000000$, one platform sorts $A$ before $B$, while another sorts $B$ before $A$.
- **Zero Pixel Impact**: All dots in that lane share identical radius $r$, identical ink $white$, and identical opacity $a$. Swapping their order in the draw list produces mathematically and visually identical rasterization.

### 4.3 Tie-Tolerant Matching Algorithm
Direct index-by-index comparison ($got[i] == want[i]$) would produce false negatives on depth ties. The verification engine must implement a **Tie-Tolerant Matcher**:

```dart
bool verifyDots(List<OrbDot> got, List<List<double>> want, double tol) {
  assert(got.length == want.length);
  final used = List<bool>.filled(want.length, false);

  for (int i = 0; i < got.length; i++) {
    final g = [got[i].x, got[i].y, got[i].z, got[i].r, got[i].white, got[i].a];
    
    // Fast path: exact index match within tolerance
    if (!used[i] && _isClose(g, want[i], tol)) {
      used[i] = true;
      continue;
    }

    // Tie resolution path: search within the depth-tied equivalence window
    int j = i;
    while (j > 0 && (want[j - 1][2] - g[2]).abs() <= tol) {
      j--;
    }

    bool matched = false;
    while (j < want.length && want[j][2] <= g[2] + tol) {
      if (!used[j] && _isClose(g, want[j], tol)) {
        used[j] = true;
        matched = true;
        break;
      }
      j++;
    }

    if (!matched) {
      // Verification failure: point does not exist within its depth-tie window
      return false;
    }
  }
  return true;
}

bool _isClose(List<double> a, List<double> b, double tol) {
  for (int k = 0; k < 6; k++) {
    if ((a[k] - b[k]).abs() > tol) return false;
  }
  return true;
}
```

---

## 5. Differential Sweep Testing Overview

In addition to the 72 static golden vectors, the upstream repository establishes verification using a **Dense Differential Sweep** (`Scripts/differential-sweep.sh` and `SweepTests.swift`).

### 5.1 Architecture
The differential sweep tests the engine against continuous temporal streams rather than isolated snapshots:
1. A Node.js child process executes Jakub Antalik's pinned TypeScript source code directly.
2. The Node process evaluates **725,149 consecutive frames** (containing over **213,000,000 dots**) and pipes raw IEEE 754 little-endian `Float64` binary data into a Unix named pipe (FIFO).
3. The native test runner consumes the binary stream, runs the native engine simultaneously, and asserts dot-for-dot and line-for-line equality.

### 5.2 Parity Results Achieved
- **Worst-case coordinate divergence**: $< 2.0 \times 10^{-9}$ pt across all 213 million dots.
- **Option calculation discrepancies**: Exactly 0 across all base, resolved, and dynamically scaled options.
- **Visual difference**: Mean raster difference $< 1/255$ intensity level against headless Chrome Canvas rasterization.

### 5.3 Flutter Implementation Recommendations
To replicate the differential sweep for Flutter:
1. Write a standalone Dart CLI script (`bin/sweep.dart` or `tool/sweep.dart`).
2. Stream frames from `node Scripts/sweep/gen.ts` via standard IPC / process pipes.
3. Decode binary `Float64List` chunks directly into typed memory.
4. Execute `OrbEngine.frame(...)` and assert bounds within $1 \times 10^{-6}$.
