`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Georgia Tech
// Engineer: Nicholas Bramhall
// 
// Design Name: Finite State Machine Lock - BUTTON LOGIC FIXED
// 
// CRITICAL FIX: Handles active-LOW buttons
// 
// This version INVERTS the button logic to handle active-LOW buttons
//
// Revision 0.04 - Fixed button polarity issue
// Revision 0.03 - Made debouncer  
// Revision 0.02 - Added metastability protection
// Revision 0.01 - File Created
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

module finite_state_machine_lock(
        input logic clk,        
        input logic rst_n,      

        input logic button_1,   // Button 1, represents a 1 (ACTIVE-LOW on most boards!)
        input logic button_2,   // Button 2, represents a 0 (ACTIVE-LOW on most boards!)

        output logic led_red,   // Red LED indicates the lock is locked
        output logic led_green  // Green LED indicates the lock is unlocked
    );

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

    // Synchronized button signals
    logic button_1_sync_r1, button_1_sync_r2, button_1_input;
    logic button_2_sync_r1, button_2_sync_r2;
    logic button_active_sync;
    
    logic input_bit;
    logic [20:0] counter;
    logic sample_valid;
    logic [3:0] password;
    logic [3:0] input_counter;
    logic [29:0] unlocked_counter;
    logic [27:0] blinky_counter; 
    
    parameter DELAY            = 21'd1500000;     // 15 ms debounce
    parameter UNLOCKED_TIMEOUT = 29'd500000000;   // 5 second timeout
    
    // ========================================
    // Metastability Protection Synchronizers
    // ========================================
    always_ff @(posedge clk) begin : synchronizers
        if(!rst_n) begin
            button_1_sync_r1 <= 1;  
            button_1_sync_r2 <= 1;
            button_2_sync_r1 <= 1;
            button_2_sync_r2 <= 1;
            button_1_input   <= 1;
        end else begin
            // Synchronize each button independently
            button_1_sync_r1 <= button_1;
            button_1_sync_r2 <= button_1_sync_r1;
            button_1_input   <= button_1_sync_r2;
            
            button_2_sync_r1 <= button_2;
            button_2_sync_r2 <= button_2_sync_r1;
        end
    end
    
 
    // Active-LOW means: button_1 = 0 when pressed, 1 when not pressed
    // button_active_sync = 1 when button is pressed
    assign button_active_sync = (!button_1_sync_r2) || (!button_2_sync_r2);

    // ========================================
    // Debouncer
    // ========================================
    always_ff @(posedge clk) begin : debouncer
        if(!rst_n) begin
            sample_valid <= 0;
            input_bit    <= 0;
            counter      <= 0;
        end else begin
            if(button_active_sync && counter < DELAY) begin
                counter <= counter + 1'b1;
            end else if (!button_active_sync && counter == DELAY) begin
                input_bit    <= !button_1_input;  
                sample_valid <= 1;
                counter      <= 0;
            end else if(!button_active_sync) begin
                sample_valid <= 0;
                counter      <= 0;
            end
        end
    end
    
    // ========================================
    // State Transition Logic (Combinational)
    // ========================================
    always_comb begin
        case (state)
            PROGRAM_0: next_state = PROGRAM_1;
            PROGRAM_1: next_state = PROGRAM_2;
            PROGRAM_2: next_state = PROGRAM_3;
            PROGRAM_3: next_state = LOCKED_0;

            LOCKED_0:   if(!sample_valid) begin
                            next_state = state;
                        end else if (sample_valid) begin
                            if(input_bit == password[3]) begin
                                next_state = LOCKED_1;
                            end else begin
                                next_state = ERROR;
                            end
                        end

            LOCKED_1:   if(!sample_valid) begin
                            next_state = state;
                        end else if (sample_valid) begin
                            if(input_bit == password[2]) begin
                                next_state = LOCKED_2;
                            end else begin
                                next_state = ERROR;
                            end
                        end

            LOCKED_2:   if(!sample_valid) begin
                            next_state = state;
                        end else if (sample_valid) begin
                            if(input_bit == password[1]) begin
                                next_state = LOCKED_3;
                            end else begin
                                next_state = ERROR;
                            end
                        end

            LOCKED_3:   if(!sample_valid) begin
                            next_state = state;
                        end else if (sample_valid) begin
                            if(input_bit == password[0]) begin
                                next_state = UNLOCKED;
                            end else begin
                                next_state = ERROR;
                            end
                        end

            UNLOCKED:   next_state = LOCKED_0;
            ERROR:      next_state = LOCKED_0;
            default:    next_state = ERROR;
        endcase
    end


    
    // ========================================
    // FSM State Machine (Sequential)
    // ========================================
    always_ff @(posedge clk) begin : Programmer
        if(!rst_n) begin 
            password         <= 0;
            input_counter    <= 0;
            unlocked_counter <= 0;
            state            <= PROGRAM_0;
        end else begin
            case (state)
                PROGRAM_0: begin
                    if (sample_valid) begin
                        state       <= next_state;
                        password[3] <= input_bit;
                    end
                end

                PROGRAM_1: begin
                    if (sample_valid) begin
                        state       <= next_state;
                        password[2] <= input_bit;
                    end
                end

                PROGRAM_2: begin
                    if (sample_valid) begin
                        state       <= next_state;
                        password[1] <= input_bit;
                    end
                end

                PROGRAM_3: begin
                    if (sample_valid) begin
                        state       <= next_state;
                        password[0] <= input_bit;
                    end
                end

                LOCKED_0: begin
                    input_counter    <= 0;
                    unlocked_counter <= 0;
                    blinky_counter   <= 0;
                    if(sample_valid) begin
                        input_counter <= input_counter + 1;
                        state         <= next_state;
                    end
                end

                LOCKED_1: begin
                    if(sample_valid) begin
                        input_counter <= input_counter + 1;
                        state         <= next_state;
                    end
                end

                LOCKED_2: begin
                    if(sample_valid) begin
                        input_counter <= input_counter + 1;
                        state         <= next_state;
                    end
                end

                LOCKED_3: begin
                    if(sample_valid) begin
                        input_counter <= input_counter + 1;
                        state         <= next_state;
                    end
                end

                ERROR: begin
                    if(sample_valid &&  (input_counter < 3'd4)) begin
                        input_counter <= input_counter + 1;
                    end else if(input_counter == 3'd4) begin
                        if(blinky_counter < 250000000) begin
                            blinky_counter <= blinky_counter + 1;
                        end else begin
                            state         <= next_state;
                            input_counter <= 0;
                        end
                    end
                end

                UNLOCKED: begin
                    unlocked_counter <= unlocked_counter + 1;
                    if(unlocked_counter == UNLOCKED_TIMEOUT - 1) begin
                        state <= next_state;
                    end
                end
            endcase
        end
    end

    // ========================================
    // Output Logic (Combinational)
    // ========================================
    always_comb begin
        case (state)
            UNLOCKED: begin
                led_red   = 1'b0;
                led_green = 1'b1;
            end

            ERROR: begin    //should blink to signify failed attempt
                if(input_counter == 3'd4)begin
                    if(blinky_counter < 50000000) begin
                        led_red = 1'b0;
                    end else if (blinky_counter < 100000000 ) begin
                        led_red = 1'b1;
                    end else if(blinky_counter < 150000000) begin
                        led_red = 1'b0;
                    end else if(blinky_counter < 200000000) begin
                        led_red = 1'b1;
                    end else if (blinky_counter < 250000000 ) begin
                        led_red = 1'b0;
                    end else begin
                        led_red = 1'b1;
                    end
                end else begin
                    led_red = 1'b1;
                end
                led_green = 1'b0;
            end

            default: begin
                led_red   = 1'b1;
                led_green = 1'b0;
            end
        endcase
    end

endmodule