# FSM Lock - 4-Digit Programmable Lock

A SystemVerilog implementation of a 4-digit programmable lock with button debouncing, metastability protection, and FPGA synthesis. Demonstrates core digital design concepts including clock domain crossing, asynchronous input handling, and finite state machines.

## Overview

The lock implements a security mechanism where users can program a 4-digit binary password at reset, then unlock by entering the same sequence. Visual feedback via LEDs indicates lock state and errors.

**Specifications:**
- 4-digit binary password (2 buttons, 16 possible combinations)
- 15ms debounce window
- 5-second auto-lock timeout after unlock
- Metastable-safe button input handling
- Hardware-tested on Basys3 FPGA (Vivado 2024.1)

## Key Implementation Details

### Clock Domain Crossing & Metastability

Asynchronous button inputs are synchronized through a 3-stage flip-flop chain before use in the debouncer:

```systemverilog
button_1_sync_r1 <= button_1;         // Stage 1: catch metastability
button_1_sync_r2 <= button_1_sync_r1;  // Stage 2: clean output
button_1_input   <= button_1_sync_r2;  // Stage 3: debouncer input
```

This approach meets FPGA timing constraints and prevents metastability issues that cause unreliable behavior on hardware. Each stage allows one clock cycle for signal settling, guaranteeing a metastable-safe output by stage 3.

### Button Polarity & Active-LOW Logic

The FPGA board uses active-LOW buttons (button pulled to ground when pressed, held HIGH by pull-up resistor otherwise). Button activity is detected by inverting the synchronized signals:

```systemverilog
assign button_active_sync = (!button_1_sync_r2) || (!button_2_sync_r2);
```

This design uses `button_1_sync_r2` and `button_2_sync_r2` for button-active detection while `button_1_input` (stage 3) provides the cleanest possible input for the debouncer timing-critical logic.

### Debouncing Strategy

The debouncer employs a hold-and-release pattern:

1. Button pressed → counter increments while active
2. Counter reaches DELAY threshold (15ms, 1,500,000 cycles @ 100 MHz)
3. Button released → sample_valid pulse fires, input captured

The debounce window rejects short glitches from button bouncing and noise. A 15ms window accommodates typical mechanical switch bounce (5-20ms range).

### State Machine Architecture

The FSM implements 10 states across 4 phases:

- **PROGRAM_0-3**: Initial programming of 4-digit password
- **LOCKED_0-3**: Password verification sequence (4 states for each digit)
- **UNLOCKED**: Success state (5-second timeout)
- **ERROR**: Failed authentication (displays visual feedback)

State transitions use combinational logic for next-state calculation and sequential logic for state updates, enabling synchronous operation with asynchronous inputs.

### Input Validation

The design validates each button press against the stored password. Incorrect input at any stage transitions to ERROR state, which displays a blinking LED for visual feedback before returning to LOCKED_0. This prevents brute-force attacks by requiring re-entry of the full sequence on failure.

## File Structure

```
Finite State Machine Lock.srcs/
├── sources_1/new/
│   └── finite_state_machine_lock.sv    # Main module (298 lines)
├── sim_1/new/
│   └── finite_state_machine_lock_tb.sv # Testbench
└── constrs_1/new/
    └── constraints.xdc                 # Pin assignments
```

## Design Decisions

### Why 3-Stage Synchronizer?

The third stage is because without it the sychronized data is updated too soon to propagate the correct data, with the extra flip flip it holds onto the correct input for the extra cycle needed.

### Button Comparison Strategy

Rather than synchronizing the OR'd button signal (which would introduce additional delay), the design synchronizes individual button signals then derives button_active combinationally. This maintains independent button timing paths while providing metastability protection where needed.

### Error State Design

Wrong password attempts increment a counter. After 4 attempts, the lock enters a 0.5-second blink state before returning to LOCKED_0. This provides user feedback while preventing rapid-fire retry attacks.

## Synthesis Results

- Device: Artix-7 (Basys3 board)
- Slice Utilization: <5%
- Maximum Clock Frequency: >100 MHz
- Critical Warnings: 0
- Latch Inference: 0

## Testing

Comprehensive testbench covers:
- Reset behavior and initialization
- Programming sequence with correct inputs
- Password verification on unlock
- Error state entry and recovery
- State machine transitions
- LED output behavior

Run simulation:
```bash
vivado -mode batch -source sim.tcl
```

Hardware testing verifies:
1. Red LED on at power-up (LOCKED state)
2. State transitions via button presses
3. Green LED on unlock
4. Auto-lock after 5 seconds
5. Error state on wrong password

## Technical Lessons

### Simulation vs Hardware

The design revealed a critical gap: simulation doesn't enforce real timing constraints on asynchronous inputs. A design that works perfectly in simulation can fail on hardware due to metastability if clock domain crossing isn't properly handled.

### Active-LOW Button Detection

Most FPGA boards use active-LOW buttons. The inverted logic (`!button_pressed`) is counterintuitive but standard. Always verify board schematic rather than assuming.

### Pulse Synchronization

Using `sample_valid` as a one-cycle pulse required careful FSM design to avoid consuming the same pulse multiple times. Edge detection logic prevents this issue.

## Usage

Program password: `button_1, button_2, button_1, button_2`
(Hold each button ~2 seconds, release)

Unlock: Repeat the programmed sequence

Reset: System resets to PROGRAM_0 on power-up or reset button

## Author

Nicholas Bramhall
Georgia Tech
May 2026
