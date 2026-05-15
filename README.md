### FPGA Implementation of CRYSTALS-Kyber Key Generation

Final Course Project for CENG3430 @CUHK, Spring 2026.

### Source attribution

The following **imported (vendored) third-party sources** are included in this repository:

- **`hash-server/`** — Keccak sponge / `hash_core_Server` and related RTL (from the hashing core in [xingyf14/CRYSTALS-Kyber-FPGA-Implementation](https://github.com/xingyf14/CRYSTALS-Kyber-FPGA-Implementation), kept under this directory).
- **`kyber-polmul-hw/`** — Kyber polynomial multiplication / NTT hardware from [acmert/kyber-polmul-hw](https://github.com/acmert/kyber-polmul-hw).
- **`neoTRNG.vhd`** — TRNG macro from [stnolting/neoTRNG](https://github.com/stnolting/neoTRNG) (VHDL file integrated at repo root).

All **other** RTL and scripts (e.g.\ `topserver.v`, `topserver_axi.v`, `a_gen.v`, `se_gen.v`, `mat_vec_mul.v`, `hash_unit.v`, `bram_sdp_12x768.v`, `pynq_script.py`, report sources, etc.) are **original work** for this course project unless a file header states otherwise.

### Academic use only

This project is for **academic purposes only**.
It is not intended for commercial use or redistribution beyond an educational context.
