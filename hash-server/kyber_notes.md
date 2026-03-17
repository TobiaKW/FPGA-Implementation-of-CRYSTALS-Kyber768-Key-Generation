CRYSTALS-Kyber768 Studies and Project plan
=========================================

## High-level goal

Establish a shared secret key **K** between Alice and Bob, then use **K** with a symmetric cipher (same key for encrypt/decrypt).

- **768**: dimension of the lattice vector.
- K is a **256-bit** key.

## Algorithms

### KeyGen()

Generates:
- **Public key** `pk`
- **Secret key** `sk`

Mathematical relation:

- \( A \cdot s + e \pmod{3329} = t \)
- \( A \): 3×3 matrix of polynomials (random, public)
- \( s \): 3×1 vector (secret key), coefficients in \([-2, 2]\)
- \( e \): 3×1 noise vector, coefficients in \([-2, 2]\)
- \( t \): 3×1 public key vector, coefficients in \([0, 3328]\)
- Each polynomial has degree up to 255.

**Noise range rationale**:
- Too small → cannot hide the secret.
- Too large → decapsulation may fail.

Both \( s \) and \( e \) typically have coefficients in \([-2, 2]\) for efficiency and security.

#### KeyGen steps

1. Generate random **seed of A** (32 bytes) and random **z** (32 bytes).
2. Expand the seed into matrix **A** (3×3 polynomials, coefficients uniform in \([0, 3328]\)).
3. Sample secret vector **s** (3 polys, coefficients from \{-2, -1, 0, 1, 2\}).
4. Sample noise vector **e** (3 polys, same coefficient range).
5. Compute **t = A · s + e**.
6. Return:
   - Public key: `pk = (seed_of_A, t)` → 1184 bytes.
   - Secret key: `sk = (s || pk || SHA3-256(pk) || z)`  
     Sizes: 768 bytes || 1184 bytes || 32 bytes || 32 bytes = 2400 bytes total.

**Important**: mod 3329 must be applied after every step, effectively after every multiplication in the matrix operations.

### Encapsulate(pk)

Alice encrypts using Bob’s public key `pk`.

1. **m ← random 256 bits**.
2. **h = SHA3-256(pk)**.
3. **(K', r) = SHA3-512(m ‖ h)**.
4. Expand **r** using SHAKE-256:
   - nonce 0,1,2 → `r_vec` (3 polys)
   - nonce 3,4,5 → `e1` (3 polys)
   - nonce 6     → `e2` (1 poly)  
   (nonce is a parameter to SHAKE that changes the output.)
5. Regenerate matrix **A** from seed in `pk`.
6. **u = Aᵀ · r_vec + e1**  (3×1 vector of polys).
7. **μ = Encode(m)**  (one poly).
8. **v = tᵀ · r_vec + e2 + μ**.
9. Compress `u`, `v`.
10. **c = (u, v)**  (the single ciphertext).
11. **K = SHAKE-256(K' ‖ SHA3-256(c))** (shared secret).

Return `(c, K)`.

Notes:
- K is the AES key used to encrypt the *real* message. m itself can be random.
- μ encoding:
  - bit 0 → coefficient 0
  - bit 1 → coefficient ≈ q/2 (1665 when q = 3329)

#### Compression

For coefficient \( x \in [0, 3328] \) and target bits **d**:

- **Compress(x, d) = ⌊(2ᵈ / q) · x⌉ mod 2ᵈ**
- **Decompress(x, d) = ⌊(q / 2ᵈ) · x⌉**

Where:
- In Kyber768:
  - d = 10 for `u`
  - d = 4 for `v`
- \( q = 3329 \)

### Decapsulate(sk, c)

Bob uses secret key `sk` and ciphertext `c`:

1. Decompress `u` and `v` (reverse of Alice’s compression with same d values).
2. Compute **noisy_μ = v − sᵀ · u**.
3. Round each coefficient of `noisy_μ`:
   - closer to 0    → bit = 0
   - closer to 1665 → bit = 1  
   This recovers **m'** (256 bits).
4. Recover Alice’s random m as **m'**.
5. Re-encapsulate: run **Encapsulate(pk, m')** to get `(c', K')`.
6. Compare:
   - If `c' == c` → return **K = K'** (success).
   - Else         → return **K = random** (reject/fail).

At the end, Alice and Bob share **K** and can use it with a symmetric cipher (e.g. AES‑256 from tiny-AES-c).

## Hashing in Kyber / project structure

- Hashing blocks (e.g. SHA3‑256) → borrow from Keccak reference hardware:  
  `https://keccak.team/hardware.html`
- NTT (large polynomial multiplication) → borrow Kyber-specific implementation:  
  `https://github.com/acmert/kyber-polmul-hw`
- This project does:
  - keygen FSM
  - encap FSM
  - decap FSM
  - testbench
  - AES‑256 with shared key K to verify correctness.

## Keccak server and FIFO interface

### FIFO bus bit structure (input FIFO)

FIFO input word layout:

- `[35:34]` = `ififo_mode[1:0]`
- `[33]`    = `ififo_absorb`
- `[32]`    = `ififo_last`
- `[31:0]`  = `ififo_din`

`ififo_wen` is a separate write-enable signal.

### Using `hash_core_Server` as a standard hash/SHAKE engine

To use this server as a **standard hash/SHAKE engine** (SHAKE128/256, SHA3‑256/512):

- **Ignore** the Kyber decode path:
  - fifo8
  - `decode_keccak`
  - ofifo0/ofifo1
- Treat **`keccak_dout`** as the standard Keccak/SHAKE output stream.

Control signals:

- **`keccak_init`**: start a new hash.
- **`ififo_wen`, `ififo_din`, `ififo_last`, `ififo_mode`**: feed the message and its padding into the input FIFO.
- **`extend`**: for SHAKE, keep squeezing/outputting more blocks.
- **`keccak_ctr`**: selects absorb/squeeze phases (1,2,5,6 are squeeze in this design).

Then **read successive 32‑bit words on `keccak_dout` each cycle while the internal squeeze phase is active.**

### Practical notes for this RTL

#### SHA3‑256 / SHA3‑512 (fixed-length digests)

1. Feed the full message through the input FIFO, marking the last word with `ififo_last`.
2. Wait for `keccak_ready` to go high.
3. Around that point, the core presents a sequence of 32‑bit words on `keccak_dout`:
   - one word per clock while its internal “squeeze” is active.
4. Collect as many words as needed:
   - SHA3‑256: 256 bits → 8 × 32‑bit words
   - SHA3‑512: 512 bits → 16 × 32‑bit words

#### SHAKE128 / SHAKE256 (extendable output)

1. Same initial steps: feed input, wait for `keccak_ready`.
2. Use `extend` to keep the core in squeezing mode so it continues generating 32‑bit words on `keccak_dout`.
3. Keep clocking and collecting `keccak_dout` until the required output length is reached.

### Summary: what matters for plain hashing

For plain SHA3/SHAKE hashing with this server:

- **Input interface**: `ififo_*` + `keccak_init`.
- **Output interface**: `keccak_dout` as a stream, with `keccak_ready` as the “absorb+permute done” marker.
- Internal Kyber-specific blocks (fifo8, `decode_keccak`, ofifo0/ofifo1) are not needed for standard hashing, but are used when sampling coefficients \< 3329 for full Kyber.

