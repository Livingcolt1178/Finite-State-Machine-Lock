# Finite State Machine Lock - Digital Design Learning Project

A 4-digit programmable lock implemented in SystemVerilog on an FPGA, demonstrating critical concepts in digital design including metastability protection, asynchronous input handling, and button debouncing.

## Project Overview

This project implements a secure lock mechanism with the following features:
- **Programmable 4-digit password** (binary digits via 2 buttons)
- **Secure password verification** against stored configuration
- **LED feedback** (green = unlocked, red = locked/error)
- **Error state with visual feedback** (blinking LED on wrong password)
- **5-second auto-lock timeout** after successful unlock
- **15ms debounce** for reliable button input

**Status**: ✓ Working on hardware (Vivado 2024.1, tested on Basys3 FPGA)

---

## Table of Contents
1. [Key Lessons Learned](#key-lessons-learned)
2. [Architecture](#architecture)
3. [Technical Deep Dives](#technical-deep-dives)
4. [Common Pitfalls Encountered](#common-pitfalls-encountered)
5. [How to Build & Test](#how-to-build--test)

---

## Key Lessons Learned

### 1. Metastability & Clock Domain Crossing

#### What is Metastability?

When an asynchronous signal violates setup/hold time on a flip-flop, the output becomes **metastable** — neither 0 nor 1 — for a short period. This is the #1 cause of obscure FPGA bugs.

```
Real button press (asynchronous):
─────────────┐
  Safe       │ Unknown (metastable!)
─────────────┴─────────────────────
            ↑
         Clock edge
    (button violates timing)
```

#### The Fix: Two-Stage Synchronizer

```systemverilog
always_ff @(posedge clk) begin
    button_1_sync_r1 <= button_1;      // Stage 1: catches metastability
    button_1_sync_r2 <= button_1_sync_r1;  // Stage 2: guarantees clean output
    button_1_input   <= button_1_sync_r2;  // Stage 3: extra safety margin
end
```

**Why 2+ stages?**
- Stage 1 **allows metastability to occur** (but contains it)
- By the time Stage 1 settles (typically <1 cycle at 100 MHz), Stage 2 captures the clean value
- Stage 3 adds extra safety margin for the debouncer

This is **industry standard** for async→sync crossing. Without it, you risk:
- Random failures in simulation that don't appear in hardware
- Designs that work at room temperature but fail at extremes
- "Glitchy" behavior that's hard to debug

**Cost**: 3 flip-flops and 2 clock cycles of latency. Completely worth it.

---

### 2. Active-LOW Button Logic (The Gotcha)

#### The Problem We Hit

Your code expected buttons to go HIGH when pressed:
```systemverilog
button_active = button_1 || button_2;  // Looking for HIGH
```

But FPGA boards use active-LOW buttons:
- Button not pressed: signal = 1 (pulled high by resistor)
- Button pressed: signal = 0 (connected to ground)

**Result**: `button_active` was always 0, so the debouncer never fired. Red LED stayed on forever.

#### The Solution

Invert the logic:
```systemverilog
// For active-LOW buttons: invert!
assign button_active_sync = (!button_1_sync_r2) || (!button_2_sync_r2);
```

Also invert when capturing which button:
```systemverilog
input_bit <= !button_1_input;  // 1 if button_1 pressed, 0 if button_2 pressed
```

#### Why This Matters

**This is probably the #1 mistake when moving from simulation to hardware:**
- Simulation doesn't care about real button polarity
- You can test with `button_1 = 1` to mean "pressed"
- Real boards don't follow your convention — they follow electrical standards

**Always check your board's schematic!** Most dev boards use active-LOW, but not all.

---

### 3. Button Debouncing & Timing Issues

#### What We Learned: Bounces Happen EVERYWHERE

Real buttons don't cleanly transition. They bounce:
```
Real button release:
1 → 0 → 1 → 0 → (finally stable at 0)
        └─ bounce

Your synchronizer sees:
button_2_sync_r2:  1 → 0 → 1 → 0 → 0 → 0 (stable)
button_active:     1 → 0 → 1 → 0 → 0 → 0 (bounces too!)

Problem: Debouncer sees the button "re-press" from bounce
         → counter resets mid-debounce
         → sample_valid never fires reliably
```

#### The Three Solutions We Considered

| Solution | Approach | Pros | Cons | Recommendation |
|---|---|---|---|---|
| **1: Use r1** | `button_active = !button_1_sync_r1` | Fast (1 cycle) | Less metastability protection | ❌ Risky |
| **2: Add 3-stage** | Extra flip-flop for button_active | Very robust | Overkill (3 cycles) | ⚠️ Over-engineered |
| **3: Sync the OR** | Synchronize button_active itself | Natural filtering, clean, standard | — | ✓ **BEST** |

#### Solution 3 Explained (What We Used)

Instead of deriving `button_active` from synchronized individual buttons, synchronize the OR signal itself:

```systemverilog
// Stage 1: OR the RAW buttons
button_active_r1 <= (!button_1) || (!button_2);

// Stage 2: Synchronize the composite signal
button_active_r2 <= button_active_r1;

// Use the synchronized version
assign button_active_sync = button_active_r2;
```

**Why this works:** The 2-stage synchronizer acts as both:
1. **Metastability protection** for the OR logic
2. **Natural bounce filter** — bounces get smoothed out by the synchronizer

This is how real systems do it. It's elegant because you get both safety AND bounce rejection without extra logic.

**Timing**: Bounces typically last 5-20ms. Your 15ms debounce window easily filters them out, but the synchronizer smooths things further.

---

### 4. Input Bit Capture & Pulse Synchronization

#### The Bug: Stale Values

After fixing the debouncer, we hit a new problem: **all 4 button presses were accepted regardless of which button was pressed.**

```systemverilog
// The problem: input_bit captured once, then held forever
if(sample_valid) begin
    input_bit <= button_1_input;  // Captured here
end
// But input_bit stays HIGH for all subsequent presses!
```

Timeline:
```
Press button_1: input_bit = 1, password[3] = 1
...time passes...
Press button_2: input_bit should = 0
              But if button_1_input hasn't updated yet,
              input_bit might still be 1!
              Wrong password accepted!
```

#### The Root Cause

**Pulse vs Level confusion:**
- `sample_valid` is a PULSE (1 clock cycle high)
- FSM logic runs every cycle
- If the FSM sees the same pulse, it might consume it multiple times

#### The Solution

Track whether the pulse was already consumed:
```systemverilog
logic sample_valid_was_high;

if(sample_valid && !sample_valid_was_high) begin
    // sample_valid just went HIGH for the first time
    input_bit <= input_bit_raw;
    sample_valid_was_high <= 1;  // Mark as consumed
end else if(!sample_valid) begin
    // sample_valid went LOW, allow next pulse
    sample_valid_was_high <= 0;
end
```

**This is called "edge detection"** — capturing signals only on rising/falling edges.

---

## Architecture

### State Machine Hierarchy

```
PROGRAM_0 ──→ PROGRAM_1 ──→ PROGRAM_2 ──→ PROGRAM_3 ──→ LOCKED_0
                                                            ↓
ERROR ←────────────────────────────────────────────← LOCKED_3
 ↓                                                      ↑
LOCKED_0 ←──────────────────────────────────────── UNLOCKED
```

### Signal Flow

```
Physical Button (async)
    ↓
[2-Stage Synchronizer] → Clean, metastable-safe button signal
    ↓
[Button Active OR] → Synchronized composite signal
    ↓
[Debouncer] → 15ms debounce window
    ↓
[sample_valid Pulse] → One-cycle notification
    ↓
[FSM] → State transitions + Password comparison
    ↓
[LED Output] → Visual feedback
```

### Key Signals

| Signal | Purpose | Notes |
|--------|---------|-------|
| `button_1_sync_r1/r2` | Synchronized individual buttons | For capturing which button was pressed |
| `button_active_sync` | "Is any button pressed?" | Synchronized composite signal |
| `sample_valid` | "Valid button press detected" | 1-cycle pulse when debounce completes |
| `input_bit` | Which button was pressed | Latched when sample_valid pulses |
| `state` | Current FSM state | PROGRAM_0-3, LOCKED_0-3, UNLOCKED, ERROR |
| `password[3:0]` | Stored 4-digit password | password[3]=digit1, password[0]=digit4 |

---

## Technical Deep Dives

### Debounce Timing

**Parameter**: `DELAY = 21'd1500000` (15 milliseconds at 100 MHz)

Calculation:
```
15 ms = 15,000,000 ns
At 100 MHz: 1 clock cycle = 10 ns
Cycles needed = 15,000,000 ns / 10 ns = 1,500,000 cycles
```

**Why 15ms?** 
- Typical mechanical button bounce: 5-20ms
- 15ms is a safe middle ground
- Longer debounce = slower lock response
- Shorter debounce = risk missing bounces

If your buttons are noisier, increase to 20-30ms. If they're cleaner, 10ms is fine.

### Active-LOW Button Detection

```systemverilog
// Test it yourself:
// button_1 = 1 (not pressed) → button_active_sync = 0
// button_1 = 0 (pressed)     → button_active_sync = 1

assign button_active_sync = (!button_1_sync_r2) || (!button_2_sync_r2);
```

Verify on oscilloscope/logic analyzer if you have one.

### Password Storage & Verification

Password stored in 4-bit register:
```systemverilog
logic [3:0] password;

// During PROGRAMMING:
PROGRAM_0: password[3] <= input_bit;  // 1st digit
PROGRAM_1: password[2] <= input_bit;  // 2nd digit
PROGRAM_2: password[1] <= input_bit;  // 3rd digit
PROGRAM_3: password[0] <= input_bit;  // 4th digit

// During UNLOCKING:
LOCKED_0: if(input_bit == password[3]) next_state = LOCKED_1;
LOCKED_1: if(input_bit == password[2]) next_state = LOCKED_2;
LOCKED_2: if(input_bit == password[1]) next_state = LOCKED_3;
LOCKED_3: if(input_bit == password[0]) next_state = UNLOCKED;
```

**Bit ordering is critical!** password[3] must match the same digit in LOCKED_0.

---

## Common Pitfalls Encountered

### Pit 1: Latches from Incomplete Assignments

**Symptom**: Synthesis warns about latches

**Cause**: Not all paths through combinational logic assign outputs

```systemverilog
// BAD: Latch inferred
always_comb begin
    if(condition1) led_red = 1'b0;
    if(condition2) led_red = 1'b1;  // Missing else!
    // What if neither? Synthesizer infers latch to remember old value
end

// GOOD: All paths covered
always_comb begin
    if(condition1) led_red = 1'b0;
    else if(condition2) led_red = 1'b1;
    else led_red = 1'b0;  // Default case explicit
end
```

**Prevention**: Use `else if` chains, always have a `default` case in combinational logic.

### Pit 2: Stale Input Values

**Symptom**: Wrong password accepted, or inputs ignored

**Cause**: Input signal captured once, then held, causing reuse of old values

**Fix**: Implement edge detection for pulse signals. Latch new values only when sample_valid rises.

### Pit 3: Button Bouncing on Release

**Symptom**: Debouncer fires inconsistently, or button press counted twice

**Cause**: Button bounces on BOTH edges (press and release)

**Prevention**: Use Solution 3 (synchronize the composite button_active signal). The synchronizer naturally filters bounce.

### Pit 4: Active-LOW vs Active-HIGH Confusion

**Symptom**: Nothing responds to button presses; red LED always on

**Cause**: Expecting active-HIGH (button = 1 when pressed) but board uses active-LOW

**Solution**: Check board schematic, invert button logic accordingly.

---

## How to Build & Test

### Prerequisites
- Vivado 2024.1 (or compatible)
- FPGA board with 2 pushbuttons and 2 LEDs (e.g., Basys3)

### Build Steps

1. **Create new project** in Vivado
2. **Add source files**:
   - `finite_state_machine_lock.sv` (main module)
   - `constraints.xdc` (pin assignments)
3. **Run synthesis** → Check for no critical warnings
4. **Run implementation** → Check for timing violations
5. **Generate bitstream** → Program FPGA

### Testing on Hardware

1. **Power on FPGA board** → Red LED should turn on (LOCKED state)
2. **Press button sequence**: button_1 → button_2 → button_1 → button_2
   - Hold each button for ~2 seconds, release
   - Should see state transitions (no visible change, but occurs internally)
3. **After 4 presses** → Green LED turns on (UNLOCKED)
4. **After 5 seconds** → Red LED turns on (auto-locked)
5. **Wrong password test**: Press button_1 four times
   - Should enter ERROR state
   - Red LED should blink (see code for blink pattern)
   - After ~0.5 seconds, returns to LOCKED_0

### Simulation Testing

Testbench includes comprehensive tests:
```bash
vivado -mode batch -source sim.tcl
```

Testbench verifies:
- ✓ Reset behavior
- ✓ Programming sequence
- ✓ Correct password unlocking
- ✓ Wrong password error detection
- ✓ State transitions
- ✓ LED behavior

---

## Lessons for Future FPGA Projects

### Golden Rules

1. **Always synchronize asynchronous inputs** with 2+ flip-flops
   - Metastability is not "maybe" — it's "when"

2. **Check button polarity** — most boards use active-LOW
   - Verify with oscilloscope or build time vs hardware discrepancy

3. **Test debouncing on real hardware**
   - Simulation bounces are not realistic
   - Real buttons have much messier transitions

4. **Use edge detection for pulse signals**
   - Implement `was_high` tracking
   - Prevents double-counting and stale values

5. **Avoid incomplete combinational logic**
   - All outputs must be assigned in all paths
   - Use `else if` chains, never bare `if` statements

6. **Document signal polarity**
   - Comments like `// ACTIVE-LOW: button = 0 when pressed`
   - Save future debugging time

### When Things Go Wrong

**"Works in simulation but not on hardware?"**
→ Check button polarity, synchronization, metastability

**"Weird intermittent behavior?"**
→ Check timing violations, setup/hold violations, metastability

**"LEDs stuck or erratic?"**
→ Check combinational logic completeness, unintended latches

**"Button presses ignored?"**
→ Check debouncer timing, button polarity, synchronizer chain

---

## References

- **Metastability**: Harris & Harris, "Digital Design & Computer Architecture"
- **Clock Domain Crossing**: Xilinx App Note XAPP531
- **Debouncing**: Jack Ganssle's switch debouncing techniques
- **IEEE 1364 (Verilog Standard)**

---

## Author

Nicholas Bramhall  
Georgia Tech, ECE Department  
May 2026

This project was a real learning experience in bridging the gap between ideal digital design (simulation) and real hardware constraints (asynchronous inputs, metastability, physical noise).

---

## License

MIT License — feel free to use this code for educational purposes

---

**Final Thought**: The hardest bugs in digital design come from things that work great in simulation but fail mysteriously on hardware. Metastability, clock domain crossing, and asynchronous inputs are the #1 culprits. Now you know how to handle them. Go forth and synchronize! 🎓
