# hash_core_Server_tb — Signal flow and why we set each

## Overview

The testbench runs in one `initial` block with five phases. All signals we drive are **inputs** to the DUT; we only **observe** DUT outputs (e.g. `keccak_ready`, `keccak_dout`, `ofifo0_empty`).

---

## Phase 1: Reset

| What we do | Signals set | Why |
|------------|-------------|-----|
| Wait 10 ns | — | Let sim start |
| Assert reset | `rst = 1` | Force all DUT registers to a known state |
| Hold 20 ns | — | At least 2 clock cycles so reset is seen |
| Release reset | `rst = 0` | DUT leaves reset and runs normally |

**Other signals:** Left at initial values (all 0). Clock is already running via `always #5 clk = ~clk`.

---

## Phase 2: Init Keccak

| What we do | Signals set | Why |
|------------|-------------|-----|
| Pulse init | `keccak_init = 1` for 20 ns, then `0` | Tell Keccak core to clear internal state and prepare for a new hash |
| Store test vector | `d = 256'h 2D7F...997C` | 8×32-bit input for the hash (same as Kyber testbench) |

**Other signals:** `extend`, `patt_bit`, `eta3_bit`, `absorb_ctr_r1`, `keccak_ctr`, FIFO signals still at init (0). We set `keccak_ctr` and `ofifo_ena` in the next step.

---

## Pre–Phase 3: Output path “ready” (before feeding)

| What we do | Signals set | Why |
|------------|-------------|-----|
| Mark squeeze stage | `keccak_ctr = 3'h1` | DUT only writes to internal FIFO when `keccak_ctr` is 1, 2, 5, or 6. We choose 1. |
| Enable output path | `ofifo_ena = 1'b1` | Needed for `ofifo_wen` inside DUT. DUT uses `ofifo_ena_r2` (2-cycle delayed), so we set it early. |
| Wait 2 cycles | `repeat(2) @(posedge clk)` | So `ofifo_ena_r2` is 1 **while** `keccak_squeeze` is still 1 (during absorb/padding). We cannot set `keccak_squeeze` (it’s a DUT output). |

**Why early:** `keccak_squeeze = ififo_req_r1 | pad_flag`. It is 1 only during absorb and padding. After `keccak_ready` it goes 0, so we must have `ofifo_ena_r2` and `keccak_ctr` ready **before** that.

---

## Phase 3: Feed input data (8 words)

| What we do | Signals set | Why |
|------------|-------------|-----|
| Loop 8 times | `i = 0..7` | One iteration per 32-bit word. |
| Write enable | `ififo_wen = 1'b1` | Input FIFO captures `din` on the next clock edge. |
| Block size | `ififo_mode = 2'b00` | 8-word block (mode 00). |
| First block | `ififo_absorb = 1'b0` | First absorb block (no previous state). |
| Last word flag | `ififo_last = (i == 7)` | 1 only on the 8th word so DUT knows to pad and then run permutation. |
| Data | `ififo_din = d[32*i +: 32]` | LSW first: word 0 = d[31:0], word 1 = d[63:32], … word 7 = d[255:224]. |
| One cycle per word | `#10` | Hold values one 10 ns cycle so FIFO sees one write per word. |
| After loop | `ififo_wen = 1'b0`, `ififo_last = 1'b0` | Stop writing; clear `last` for next run if any. |

**DUT does:** Reads from input FIFO, absorbs 8 words, sees `last`, pads with zeros, runs Keccak permutation, then asserts `keccak_ready` when done.

---

## Phase 4: Wait for permutation done

| What we do | Signals set | Why |
|------------|-------------|-----|
| Sync to clock | `@(posedge clk)` | Align to DUT clock. |
| Wait for done | `wait(keccak_ready == 1'b1)` | Don’t proceed until Keccak has finished (DUT output). |
| One more edge | `@(posedge clk)` | Let result settle. |

**We don’t set any new inputs here;** we only wait on the DUT output `keccak_ready`.

---

## Phase 5: Observe result and try to read ofifo0

| What we do | Signals set | Why |
|------------|-------------|-----|
| Log raw hash | `$display("keccak_ready seen. keccak_dout = %h", keccak_dout)` | With unmodified server, `keccak_squeeze` is 0 after `keccak_ready`, so the main thing we can rely on is the raw 32-bit output on `keccak_dout`. |
| Pipeline delay | `repeat(32) @(posedge clk)` | Give decode/rejection path time to fill in case any data was captured when `keccak_squeeze` was 1. |
| Read ofifo0 | Loop: `ofifo0_req = 1` → `@(posedge clk)` → `ofifo0_req = 0` → `$display(ofifo0_dout)` → `@(posedge clk)` | If ofifo0 has data (`ofifo0_empty == 0`), each pulse of `ofifo0_req` reads one 24-bit word. |
| Safety limit | Loop exits when `read_count >= 64` or `ofifo0_empty == 1` | Prevents infinite loop if ofifo0 never empties. |
| Finish | `$finish` | End simulation. |

**Note:** With the **unmodified** `hash_core_Server`, `keccak_squeeze` stays 0 after `keccak_ready`, so the internal FIFO may never get the final hash and **ofifo0 may stay empty**. The TB still tries to read so it works if you ever use a modified or different core that keeps the output path active.

---

## Summary table (signals we set and when)

| Signal | Phase | Value | Why |
|--------|--------|--------|-----|
| rst | 1 | 1 then 0 | Reset DUT |
| keccak_init | 2 | 1 then 0 | Init Keccak core |
| d | 2 | 256-bit constant | Test vector |
| keccak_ctr | Pre-3 | 3'h1 | Allow internal FIFO writes when keccak_squeeze is 1 |
| ofifo_ena | Pre-3 | 1 | Enable output path; need early for ofifo_ena_r2 |
| ififo_wen | 3 | 1 in loop, 0 after | Write 8 words into input FIFO |
| ififo_mode | 3 | 2'b00 | 8-word block |
| ififo_absorb | 3 | 0 | First block |
| ififo_last | 3 | 1 on last word only | Triggers padding and permutation |
| ififo_din | 3 | d[32*i +: 32] | The 8 words |
| ofifo0_req | 5 | 1 then 0 per read | Read from output FIFO if not empty |

All other DUT inputs stay at 0 (extend, patt_bit, eta3_bit, absorb_ctr_r1, ofifo1_req) for this single-block test.
