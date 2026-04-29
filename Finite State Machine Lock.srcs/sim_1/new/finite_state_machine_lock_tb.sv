`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/24/2026 02:59:57 PM
// Design Name: 
// Module Name: finite_state_machine_lock_tb
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
    logic [3:0] state;
    logic [3:0] next_state;
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

    //tasks
    task check(input string test, input logic expected, input logic got);
        begin
            if(expected == got) begin
                $display("[%d]passed!  test: %s, got: %s, expected: %s", $time, test, got, expected);
            end else begin
                $error("[%d]ERROR  test: %s, got: %s, expected: %s", $time, test, got, expected);
            end
        end
    endtask

    task wait_clk(input int N);
        begin
            repeat(N) @(posedge clk);
        end 
    endtask

    task wait_cycle(input int N);
        begin
            repeat(N * 255000) @(posedge clk);
        end
    endtask

    task program_lock(input int a, input int b, input int c, input int d);
        check("programming", PROGRAM_0, state);
        button_1 = a;
        button_2 = !button_1;
        wait_cycle(1);

        check("programming", PROGRAM_1, state);
        button_1 = b;
        button_2 = !button_1;
        wait_cycle(1);

        check("programming", PROGRAM_2, state);
        button_1 = c;
        button_2 = !button_1;
        wait_cycle(1);

        check("programming", PROGRAM_3, state);
        button_1 = d;
        button_2 = !button_1;
        wait_cycle(1);

        check("programming", LOCKED_0, state);
    endtask

    task button_1_input(input string timing);
        begin
            if (timing == "start") begin
                button_1 = 1;
                wait_clk(1);
                button_1  = 0;
                wait_clk(254);
            end else if (timing == "middle") begin
                button_1 = 0;
                wait_clk(127);
                button_1  = 1;
                wait_clk(1);
                button_1  = 0;
                wait_clk(127);
            end else begin
                button_1 = 0;
                wait_clk(254);
                button_1 = 1;
                wait_clk(1);
                button_1 = 0;
            end
        end
    endtask

    
    task button_2_input(input string timing);
        begin
            if (timing == "start") begin
                button_2 = 1;
                wait_clk(1);
                button_2  = 0;
                wait_clk(254);
            end else if (timing == "middle") begin
                button_2 = 0;
                wait_clk(127);
                button_2  = 1;
                wait_clk(1);
                button_2  = 0;
                wait_clk(127);
            end else begin
                button_2 = 0;
                wait_clk(254);
                button_2 = 1;
                wait_clk(1);
                button_2 = 0;
            end
        end
    endtask

    task rst();
        begin
            rst_n = 0;
            repeat(5) @(posedge clk);
            rst_n = 1;
            wait_cycle(1);  
        end
    endtask

    // assert property (@(posedge clk) 
    //     (state != 4'b1000) -> (led_red == 1'b1)
    // ) else $error("Red LED should be on when locked!");
    
    // // Green LED rule: Only on when UNLOCKED
    // assert property (@(posedge clk) 
    //     (state == 4'b1000) -> (led_green == 1'b1)
    // ) else $error("Green LED should be on when unlocked!");
    
    // // Mutual exclusion: Can't have both LEDs on
    // assert property (@(posedge clk) 
    //     !(led_red & led_green)
    // ) else $error("Both LEDs can't be on!");

    initial begin
        rst();
        //===============
        //Test 1: rst check
        //===============
        check("rst test: check password",           0,  dut.password);
        check("rst test: check counter",            0,  dut.counter);
        check("rst test: check input",              0,  dut.input_bit);
        check("rst test: check unlocked_counter",   0,  dut.unlocked_counter);
        check("rst test: check input_counter",      0,  dut.input_counter);
        check("rst test: check state",              PROGRAM_0,  state);

        //=============
        // Test 2: test programmability
        //=============
        program_lock(1, 0, 1, 0);
        check("programmability test: check state",      LOCKED_0,  state);
        check("programmability test: check counter",    0,  dut.counter);
        check("programmability test: check password",   1010,  dut.password);

        //=============
        // Test 3: test input 1
        //=============
        button_1_input("start");
        check("input 1 test: check state",              LOCKED_1,  state);
        check("input 1 test: check counter",            0,  dut.counter);
        check("input 1 test: check input",              1,  dut.input_bit);
        check("input 1 test: check input_counter",      1,  dut.input_counter);

        //=============
        // Test 4: test input 2
        //=============
        button_2_input("start");
        check("input 2 test: check state",              LOCKED_2,  state);
        check("input 2 test: check counter",            0,  dut.counter);
        check("input 2 test: check input",              0,  dut.input_bit);
        check("input 2 test: check input_counter",      2,  dut.input_counter);

        //=============
        // Test 5: test input 3
        //=============
        button_1_input("start");
        check("input 3 test: check state",              LOCKED_3,  state);
        check("input 3 test: check counter",            0,  dut.counter);
        check("input 3 test: check input",              1,  dut.input_bit);
        check("input 3 test: check input_counter",      3,  dut.input_counter);

        //=============
        // Test 6: test input 4
        //=============
        button_2_input("start");
        check("input 4 test: check state",              UNLOCKED,  state);
        check("input 4 test: check counter",            0,  dut.counter);
        check("input 4 test: check input",              0,  dut.input_bit);
        check("input 4 test: check input_counter",      4,  dut.input_counter);


        //=============
        // Test 7: test Unlocked
        //=============
        check("Unlocked test: check state",             UNLOCKED,  state);
        check("Unlocked test: check counter",           0,  dut.counter);
        check("Unlocked test: check unlocked_counter",  0,  dut.unlocked_counter);
        @(posedge clk);
        check("Unlocked test: check state",             UNLOCKED,  state);
        check("Unlocked test: check counter",           1,  dut.counter);
        check("Unlocked test: check unlocked_counter",  1,  dut.unlocked_counter);
        @(posedge clk);
        check("Unlocked test: check state",             UNLOCKED,  state);
        check("Unlocked test: check counter",           2,  dut.counter);
        check("Unlocked test: check unlocked_counter",  2,  dut.unlocked_counter);
        @(posedge clk);
        check("Unlocked test: check state",             UNLOCKED,  state);
        check("Unlocked test: check counter",           3,  dut.counter);
        check("Unlocked test: check unlocked_counter",  3,  dut.unlocked_counter);
        @(posedge clk);
        check("Unlocked test: check state",             UNLOCKED,  state);
        check("Unlocked test: check counter",           4,  dut.counter);
        check("Unlocked test: check unlocked_counter",  4,  dut.unlocked_counter);
        @(posedge clk);
        check("Unlocked test: check state",             UNLOCKED,  state);
        check("Unlocked test: check counter",           5,  dut.counter);
        check("Unlocked test: check unlocked_counter",  5,  dut.unlocked_counter);
        @(posedge clk);
        check("Unlocked test: check state",             UNLOCKED,  state);
        check("Unlocked test: check counter",           6,  dut.counter);
        check("Unlocked test: check unlocked_counter",  6,  dut.unlocked_counter);
        @(posedge clk);
        check("Unlocked test: check state",             UNLOCKED,  state);
        check("Unlocked test: check counter",           7,  dut.counter);
        check("Unlocked test: check unlocked_counter",  7,  dut.unlocked_counter);
        @(posedge clk);
        check("Unlocked test: check state",             LOCKED_0,  state);
        check("Unlocked test: check counter",           0,  dut.counter);
        check("Unlocked test: check unlocked_counter",  0,  dut.unlocked_counter);

        //=============
        // Test 8: test ERROR
        //=============
        rst();
        program_lock( 0, 1, 0, 1);
        button_1_input("start");
        check("ERROR test: check state",              ERROR,  state);
        check("ERROR test: check counter",            1,  dut.counter);
        check("ERROR test: check input",              1,  dut.input_bit);
        check("ERROR test: check input_counter",      1,  dut.input_counter);
        button_1_input("start");
        check("ERROR test: check state",              ERROR,  state);
        check("ERROR test: check counter",            2,  dut.counter);
        check("ERROR test: check input",              1,  dut.input_bit);
        check("ERROR test: check input_counter",      2,  dut.input_counter);
        button_1_input("start");
        check("ERROR test: check state",              ERROR,  state);
        check("ERROR test: check counter",            3,  dut.counter);
        check("ERROR test: check input",              1,  dut.input_bit);
        check("ERROR test: check input_counter",      3,  dut.input_counter);
        button_1_input("start");
        check("ERROR test: check state",              ERROR,  state);
        check("ERROR test: check counter",            4,  dut.counter);
        check("ERROR test: check input",              1,  dut.input_bit);
        check("ERROR test: check input_counter",      4,  dut.input_counter);
        wait_cycle(1);
        check("ERROR test: check state",              LOCKED_0,  state);
        check("ERROR test: check counter",            0,  dut.counter);
        check("ERROR test: check input",              1,  dut.input_bit);
        check("ERROR test: check input_counter",      0,  dut.input_counter);


        $finish;

    end
endmodule
