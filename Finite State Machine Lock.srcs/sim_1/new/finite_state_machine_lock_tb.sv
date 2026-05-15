`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Georgia Tech
// Engineer: Nicholas Bramhall
// 
// Create Date: 04/24/2026
// Design Name: FSM Lock Testbench (Updated for Release-on-Hold Debouncer)
// Module Name: finite_state_machine_lock_tb
// Project Name: finite_state_machine_lock
//
// Description: Testbench for 4-digit FSM lock with debouncing
// New debouncer behavior: press button -> hold for DELAY cycles -> release to trigger
//
// Revision 0.02 - Updated for new debouncer
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////

module finite_state_machine_lock_tb();

    // ========================================
    // Testbench Signals
    // ========================================
    logic clk;
    logic rst_n;
    logic button_1;
    logic button_2;
    logic led_red;
    logic led_green;
    
    // Internal signal monitors (for debugging)
    typedef enum logic [3:0] {
        PROGRAM_0   = 4'b0000,
        PROGRAM_1   = 4'b0001,
        PROGRAM_2   = 4'b0010,
        PROGRAM_3   = 4'b0011,
        LOCKED_0    = 4'b0100,
        LOCKED_1    = 4'b0101,
        LOCKED_2    = 4'b0110,
        LOCKED_3    = 4'b0111,
        UNLOCKED    = 4'b1000,
        ERROR       = 4'b1001
    } state_t;

    state_t state, next_state;
    
    // ========================================
    // DUT Instantiation
    // ========================================
    finite_state_machine_lock dut (
        .clk(clk),
        .rst_n(rst_n),
        .button_1(button_1),
        .button_2(button_2),
        .led_red(led_red),
        .led_green(led_green)
    );
    
    // Access internal signals for debugging
    assign state = dut.state;
    assign next_state = dut.next_state;
 
    // ========================================
    // Clock Generation (100 MHz) 
    // ========================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10 ns period = 100 MHz
    end

    // ========================================
    // Helper Tasks
    // ========================================
    
    task check(input string test, input logic[33:0] expected, input logic[33:0] got);
        begin
            if(expected == got) begin
                $display("[%0t ns] ✓ PASS: %s | Expected: %h, Got: %h", $time, test, expected, got);
            end else begin
                $error("[%0t ns] ✗ FAIL: %s | Expected: %h, Got: %h", $time, test, expected, got);
            end
        end
    endtask

    task wait_clk(input int N);
        begin
            repeat(N) @(posedge clk);
        end 
    endtask

    // Wait for debouncer counter to reset (sample_valid pulse completes)
    task wait_for_debounce();
        begin
            wait(dut.sample_valid == 1'b1);  // Wait for sample_valid to pulse
            @(posedge clk);
            wait(dut.sample_valid == 1'b0);  // Wait for it to go back low
            @(posedge clk);
        end 
    endtask

    // ========================================
    // Button Input Tasks
    // ========================================
    
    task button_1_press();
        begin
            button_1 = 1'b0;
            button_2 = 1'b1;
            wait_clk(dut.DELAY + 1);  // Hold until counter reaches DELAY
            button_1 = 1'b1;           // Release to trigger
            button_2 = 1'b1;
            wait_for_debounce();       // Wait for sample_valid pulse
        end
    endtask

    task button_2_press();
        begin
            button_1 = 1'b1;
            button_2 = 1'b0;
            wait_clk(dut.DELAY + 1);  // Hold until counter reaches DELAY
            button_1 = 1'b1;           // Release to trigger
            button_2 = 1'b1;
            wait_for_debounce();       // Wait for sample_valid pulse
        end
    endtask

    // Early release (before DELAY) - should NOT trigger
    task button_1_early_release();
        begin
            button_1 = 1'b0;
            button_2 = 1'b1;
            wait_clk(dut.DELAY / 2);  // Hold for half the debounce time
            button_1 = 1'b1;
            button_2 = 1'b1;
            wait_clk(10);              // Wait for counter to reset
        end
    endtask

    task program_lock(input int a, input int b, input int c, input int d);
        begin
            check("PROGRAM_0 state", PROGRAM_0, state);
            
            // Program digit 1
            if (a == 1) button_1_press();
            else        button_2_press();
            check("PROGRAM_1 state", PROGRAM_1, state);
            
            // Program digit 2
            if (b == 1) button_1_press();
            else        button_2_press();
            check("PROGRAM_2 state", PROGRAM_2, state);
            
            // Program digit 3
            if (c == 1) button_1_press();
            else        button_2_press();
            check("PROGRAM_3 state", PROGRAM_3, state);
            
            // Program digit 4
            if (d == 1) button_1_press();
            else        button_2_press();
            check("LOCKED_0 state (after programming)", LOCKED_0, state);
        end
    endtask

    task rst();
        begin
            rst_n = 0;
            button_1 = 1;
            button_2 = 1;
            repeat(5) @(posedge clk);
            rst_n = 1;
            wait_clk(2);
        end
    endtask

    // ========================================
    // Main Testbench
    // ========================================
    initial begin
        rst();
        
        //===============
        // Test 1: Reset Check
        //===============
        $display("\n========== TEST 1: Reset Check ==========");
        check("password after reset",           0,  dut.password);
        check("counter after reset",            0,  dut.counter);
        check("input_bit after reset",          0,  dut.input_bit);
        check("unlocked_counter after reset",   0,  dut.unlocked_counter);
        check("input_counter after reset",      0,  dut.input_counter);
        check("state after reset",              PROGRAM_0,  state);
        check("sample_valid after reset",       0,  dut.sample_valid);

        //=============
        // Test 2: Programming Lock
        //=============
        $display("\n========== TEST 2: Programming Lock (1010) ==========");
        program_lock(1, 0, 1, 0);
        check("password after programming",   4'b1010,  dut.password);
        check("sample_valid cleared",         0,        dut.sample_valid);

        //=============
        // Test 3: Correct Input - Digit 1
        //=============
        $display("\n========== TEST 3: Correct Input Digit 1 (should be 1) ==========");
        button_1_press();
        check("state after digit 1",          LOCKED_1,  state);
        check("input_bit (should be 1)",      1,         dut.input_bit);
        check("input_counter",                1,         dut.input_counter);

        //=============
        // Test 4: Correct Input - Digit 2
        //=============
        $display("\n========== TEST 4: Correct Input Digit 2 (should be 0) ==========");
        button_2_press();
        check("state after digit 2",          LOCKED_2,  state);
        check("input_bit (should be 0)",      0,         dut.input_bit);
        check("input_counter",                2,         dut.input_counter);

        //=============
        // Test 5: Correct Input - Digit 3
        //=============
        $display("\n========== TEST 5: Correct Input Digit 3 (should be 1) ==========");
        button_1_press();
        check("state after digit 3",          LOCKED_3,  state);
        check("input_bit (should be 1)",      1,         dut.input_bit);
        check("input_counter",                3,         dut.input_counter);

        //=============
        // Test 6: Correct Input - Digit 4 (Unlock)
        //=============
        $display("\n========== TEST 6: Correct Input Digit 4 (should be 0, UNLOCK) ==========");
        button_2_press();
        check("state after digit 4",          UNLOCKED,  state);
        check("input_bit (should be 0)",      0,         dut.input_bit);
        check("input_counter",                4,         dut.input_counter);

        //=============
        // Test 7: UNLOCKED State
        //=============
        $display("\n========== TEST 7: UNLOCKED State (5 second timeout) ==========");
        check("unlocked_counter at start",    0,         dut.unlocked_counter);
        check("led_green should be ON",       1,         led_green);
        check("led_red should be OFF",        0,         led_red);
        
        // Wait a shorter time to verify it stays unlocked
        wait_clk(100);
        check("still unlocked after 100 cycles", UNLOCKED, state);
        check("unlocked_counter incrementing",   100,      dut.unlocked_counter);

        //=============
        // Test 8: ERROR State (Wrong Password)
        //=============
        $display("\n========== TEST 8: ERROR State (Wrong Password) ==========");
        rst();
        program_lock(0, 1, 0, 1);  // Program: 0101
        
        // Try to unlock with wrong first digit (send 1 instead of 0)
        button_1_press();
        check("ERROR state triggered",        ERROR,     state);
        check("led_red should be ON",         1,         led_red);
        check("led_green should be OFF",      0,         led_green);
        check("input_counter in ERROR",       1,         dut.input_counter);
        
        // Need 4 wrong inputs to return to LOCKED_0
        button_1_press();
        check("ERROR still active (2 inputs)", ERROR,    state);
        check("input_counter",                2,         dut.input_counter);
        
        button_1_press();
        check("ERROR still active (3 inputs)", ERROR,    state);
        check("input_counter",                3,         dut.input_counter);
        
        button_1_press();
        @(posedge clk) //an extra posedge clk to give it time for the 4th input bit to propagate
        check("Back to LOCKED_0 after 4 errors", LOCKED_0, state);
        check("input_counter reset",          0,         dut.input_counter);

        //=============
        // Test 9: Early Button Release (Debounce Failure)
        //=============
        $display("\n========== TEST 9: Early Release (Should NOT trigger) ==========");
        button_1_early_release();
        check("should still be in LOCKED_0",  LOCKED_0,  state);
        check("sample_valid should be 0",     0,         dut.sample_valid);

        //=============
        // Test 10: Programming Mode with Wrong Inputs
        //=============
        $display("\n========== TEST 10: Program Different Lock (1111) ==========");
        rst();
        program_lock(1, 1, 1, 1);
        check("new password set to 1111",     4'b1111,   dut.password);
        
        button_1_press();
        check("digit 1 correct",              LOCKED_1,  state);
        button_1_press();
        check("digit 2 correct",              LOCKED_2,  state);
        button_1_press();
        check("digit 3 correct",              LOCKED_3,  state);
        button_1_press();
        check("ALL UNLOCKED",                 UNLOCKED,  state);
        check("led_green on",                 1,         led_green);

        $display("\n========== ALL TESTS COMPLETE ==========");
        $finish;

    end

endmodule