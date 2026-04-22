`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/14/2026 12:34:14 PM
// Design Name: 
// Module Name: finite_state_machine_lock
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module finite_state_machine_lock(
        input logic clk;        
        input logic rst_n;      

        input logic button_1;   //button 1, represents a 1;
        input logic button_2;   //button 2, represents a 0;

        output logic led_red;   //red led indicates the lock is locked
        output logic led_green; //green led indicates the lock is unlocked
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

        UNLOCKED    = 4'b1000   //unlocked state, waits for 5 seconds before locking again.
    } state_t;

    state_t current_state, next_state;
    logic [3:0] password;
    logic input;
    logic [7:0] counter;
    logic sampled;
    logic [3:0] password;
    // State transition logic
    always_comb begin
		case (state)
			PROGRAM_0: next_state = PROGRAM_1;
            PROGRAM_1: next_state = PROGRAM_2;
            PROGRAM_2: next_state = PROGRAM_3;
            PROGRAM_3: next_state = LOCKED_0;

            LOCKED_0:   if(!sample) begin
                            next_state = state;
                        end else if (sample) begin
                            if(pass) begin
                                next_state = LOCKED_1;
                            end else begin
                                next_state = ERROR;
                            end
                        end

            LOCKED_1:   if(!sample) begin
                            next_state = state;
                        end else if (sample) begin
                            if(pass) begin
                                next_state = LOCKED_2;
                            end else begin
                                next_state = ERROR;
                            end
                        end
		
            LOCKED_2:   if(!sample) begin
                        next_state = state;
                        end else if (sample) begin
                            if(pass) begin
                                next_state = LOCKED_3;
                            end else begin
                                next_state = ERROR;
                            end
                        end
        
            LOCKED_3:   if(!sample) begin
                            next_state = state;
                        end else if (sample) begin
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
            counter <= 0;
            sampled <= 0;
            input   <= 0;
        end else begin
            if (counter == 8d'255) begin                    //first check to see if counter is maxxed and see if its a new a cycle.
                counter <= 0;          
                sampled <= 0;
                input   <= 0;
            end else begin                                  //if it isn't maxed out raise the counter and check for an input.
                counter <= counter + 1;
                if((button_1 || button_2) && !sampled) begin    //if there is an input and it hasn't been sampled
                    case({(button_1),(button_2)})               //if there was an input, from which button, assign input based on that. and record it as sampled for this cycle
                        2'b01:   input <= 0;
                        2'b10:   input <= 1;
                        2'b11:   sampled <= 0;
                        default: sampled <= 0;  //TODO: fix this logic 
                    endcase
                    sampled <= 1;
                end
            end
        end
    end

    always_ff @( posedge clk) begin : Programmer


        case (state) 
            PROGRAM_0: begin
                if (sample && (counter == 8d'255)) begin
                    state = next;
                    password[3] = input;
                end
            end

            PROGRAM_1: begin
                if (sample && (counter == 8d'255)) begin
                    state = next;
                    password[2] = input;
                end
            end

            PROGRAM_2: begin
                if (sample && (counter == 8d'255)) begin
                    state = next;
                    password[1] = input;
                end
            end

            PROGRAM_3: begin
                if (sample && (counter == 8d'255)) begin
                    state = next;
                    password[0] = input;
                end
            end

            LOCKED_0: begin
                pass = 0;
                if(sample && (counter == 8d'255)) begin
                    if( input == password[3] ) begin
                        pass = 1;
                    end
                    state = next;
                end
            end

            LOCKED_1: begin
                pass = 0;
                if(sample && (counter == 8d'255)) begin
                    if( input == password[2] ) begin
                        pass = 1;
                    end
                    state = next;
                end
            end

            LOCKED_2: begin
                pass = 0;
                if(sample && (counter == 8d'255)) begin
                    if( input == password[1] ) begin
                        pass = 1;
                    end
                    state = next;
                end
            end

            LOCKED_3: begin
                pass = 0;
                if(sample && (counter == 8d'255)) begin
                    if( input == password[0] ) begin
                        pass = 1;
                    end
                    state = next;
                end
            end

            ERROR: begin
                if((input_counter == 3d'4) && (counter == 8d'255)) begin
                    state <= next_state;
                end
            end

            UNLOCKED: begin
                
            end
        endcase

    end

endmodule
