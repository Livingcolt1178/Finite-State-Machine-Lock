`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Georgia Tech
// Engineer: Nicholas Bramhall
// 
// Create Date: 04/14/2026 12:34:14 PM
// Design Name: Finite State Machine Lock with Programming Mode
// Module Name: finite_state_machine_lock
// Project Name: finite_state_machine_lock
// Target Devices: 
// Tool Versions: Vivado 2024.1
// Description: 4-digit FSM-based lock with programming mode, debouncing, and LED feedback
//
// Clock: 100 MHz
// Button debounce time: ~2.55ms (sample counter = 255)
// Unlock hold time: ~5 seconds
// Programming LED blink: ~1 Hz
//
// Dependencies: None
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


module finite_state_machine_lock(
        input logic clk,        
        input logic rst_n,      

        input logic button_1,   //button 1, represents a 1;
        input logic button_2,   //button 2, represents a 0;

        output logic led_red,   //red led indicates the lock is locked
        output logic led_green //green led indicates the lock is unlocked
    );

    typedef enum logic [3:0] {
        PROGRAM_0   = 4'b0000,  //initial state, waiting for the first button press
        PROGRAM_1   = 4'b0001,  //2nd digit in password
        PROGRAM_2   = 4'b0010,  //3rd digit in password
        PROGRAM_3   = 4'b0011,  //4th digit in password
    
        LOCKED_0    = 4'b0100,  //locked state, must match 1st digit of password
        LOCKED_1    = 4'b0101,  //locked state, must match 2nd digit of password
        LOCKED_2    = 4'b0110,  //locked state, must match 3rd digit of password
        LOCKED_3    = 4'b0111,  //locked state, must match 4th digit of password

        UNLOCKED    = 4'b1000,   //unlocked state, waits for 5 seconds before locking again.
        ERROR       = 4'b1001   //Made a mistake in enterring Password
    } state_t;

    state_t state, next_state;

    logic pass;
    logic input_bit;
    logic [7:0] counter;
    logic sample_valid;
    logic [3:0] password;
    logic [3:0] input_counter;
    logic [3:0] unlocked_counter;
    parameter COUNTER_MAX = 8'd255;
    parameter UNLOCKED_TIMEOUT = 3'd7;
    
    // State transition logic
    always_comb begin
		case (state)
			PROGRAM_0: next_state = PROGRAM_1;
            PROGRAM_1: next_state = PROGRAM_2;
            PROGRAM_2: next_state = PROGRAM_3;
            PROGRAM_3: next_state = LOCKED_0;

            LOCKED_0:   if(!sample_valid) begin
                            next_state = state;
                        end else if (sample_valid) begin
                            if(pass) begin
                                next_state = LOCKED_1;
                            end else begin
                                next_state = ERROR;
                            end
                        end

            LOCKED_1:   if(!sample_valid) begin
                            next_state = state;
                        end else if (sample_valid) begin
                            if(pass) begin
                                next_state = LOCKED_2;
                            end else begin
                                next_state = ERROR;
                            end
                        end
		
            LOCKED_2:   if(!sample_valid) begin
                        next_state = state;
                        end else if (sample_valid) begin
                            if(pass) begin
                                next_state = LOCKED_3;
                            end else begin
                                next_state = ERROR;
                            end
                        end
        
            LOCKED_3:   if(!sample_valid) begin
                            next_state = state;
                        end else if (sample_valid) begin
                            if(pass) begin
                                next_state = UNLOCKED;
                            end else begin
                                next_state = ERROR;
                            end
                        end
        
            UNLOCKED:   next_state = LOCKED_0;

            ERROR:      next_state = LOCKED_0;
        
            default: next_state = ERROR;
        
        endcase
	end

    always_ff @( posedge clk ) begin : sample_cycler
        if(!rst_n) begin
            counter         <= 0;
            sample_valid    <= 0;
            input_bit       <= 0;
        end else begin
            if (counter == COUNTER_MAX) begin                    //first check to see if counter is maxxed and see if its a new a cycle.
                counter <= 0;          
                sample_valid <= 0;
            end else begin                                  //if it isn't maxed out raise the counter and check for an input.
                counter <= counter + 1;
                if((button_1 || button_2) && !sample_valid) begin
                    input_bit <= button_1;  // 1 if button_1, 0 if button_2
                    sample_valid <= 1;
                end
            end
        end
    end
    

    always_ff @( posedge clk) begin : Programmer
        if(!rst_n) begin 
            password <= 0;
            input_counter <= 0;
            unlocked_counter <= 0;
            state           <= PROGRAM_0;
        end else begin
            case (state)
                PROGRAM_0: begin
                    if (sample_valid && (counter == COUNTER_MAX)) begin
                        state <= next_state;
                        password[3] = input_bit;
                    end
                end

                PROGRAM_1: begin
                    if (sample_valid && (counter == COUNTER_MAX)) begin
                        state <= next_state;
                        password[2] = input_bit;
                    end
                end

                PROGRAM_2: begin
                    if (sample_valid && (counter == COUNTER_MAX)) begin
                        state <= next_state;
                        password[1] = input_bit;
                    end
                end

                PROGRAM_3: begin
                    if (sample_valid && (counter == COUNTER_MAX)) begin
                        state <= next_state;
                        password[0] = input_bit;
                    end
                end

                LOCKED_0: begin
                    pass = 0;
                    input_counter <= 0;
                    unlocked_counter <= 0;
                    if(sample_valid && (counter == COUNTER_MAX)) begin
                        if( input_bit == password[3] ) begin
                            pass = 1;
                        end
                        input_counter <= input_counter + 1;
                        state <= next_state;
                    end
                end

                LOCKED_1: begin
                    pass = 0;
                    if(sample_valid && (counter == COUNTER_MAX)) begin
                        if( input_bit == password[2] ) begin
                            pass = 1;
                        end
                        input_counter <= input_counter + 1;
                        state <= next_state;
                    end
                end

                LOCKED_2: begin
                    pass = 0;
                    if(sample_valid && (counter == COUNTER_MAX)) begin
                        if( input_bit == password[1] ) begin
                            pass = 1;
                        end
                        input_counter <= input_counter + 1;
                        state <= next_state;
                    end
                end

                LOCKED_3: begin
                    pass = 0;
                    if(sample_valid && (counter == COUNTER_MAX)) begin
                        if( input_bit == password[0] ) begin
                            pass = 1;
                        end
                        input_counter <= input_counter + 1;
                        state <= next_state;
                    end
                end

                ERROR: begin
                    if(sample_valid && (counter == COUNTER_MAX)) begin
                        input_counter <= input_counter + 1;
                        if((input_counter == 3'd4)) begin
                            state <= next_state;
                            input_counter <= 0;
                        end
                    end
                end

                UNLOCKED: begin
                    unlocked_counter <= unlocked_counter + 1;
                    if((unlocked_counter == UNLOCKED_TIMEOUT - 1) && counter == COUNTER_MAX) begin
                        state <= next_state;
                    end

                end
            endcase
        end
    end

    always_comb begin
        if(!rst_n) begin 
            led_green = 1'b0;
            led_red = 1'b0;
        end else begin
            case (state)
                UNLOCKED: begin
                    led_red = 1'b0;
                    led_green = 1'b1;
                end

                default: begin
                    led_red = 1'b1;
                    led_green = 1'b0;
                end
            endcase
        end
    end
endmodule
