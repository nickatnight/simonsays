//
// Simon Says -- Final -- COMPE 470L -- Fall 2014 -- 814584401
//
module ioTest (input  M_CLOCK,	  // FPGA clock
		   input  [3:0] IO_PB,	  // IO Board Pushbutton Switches 
		   input  [7:0] IO_DSW,	  // IO Board Dip Switchs
	    	output reg [3:0] F_LED,	  // FPGA LEDs
	   	output reg [7:0] IO_LED,	  // IO Board LEDs
		   output reg [3:0] IO_SSEGD, // IO Board Seven Segment Digits			
		   output reg [7:0] IO_SSEG,  // 7=dp, 6=g, 5=f,4=e, 3=d,2=c,1=b, 0=a
		   output IO_SSEG_COL);	  // Seven segment column
	
	// ************************************ INITIALIZATION ************************************
	
	// parameters for the different states of the state machine
	parameter s0 = 3'b000, s1 = 3'b001, s2 = 3'b010, s3 = 3'b011, s4 = 3'b100, s5 = 3'b101;	
	
	// registers for logic
	reg [7:0] next_level_state, sevSeg3 = 0, sevSeg4 = 1;	
	reg [2:0] state = 0, refreshState = 0;
	reg [3:0] scrollCountGreet = 0, scrollCountLose = 0;
	reg [7:0] sCount = 0, level_state, firstBlock = 0, secondBlock = 0, thirdBlock = 0, fourthBlock = 0, dig1 = 0, dig2 = 0;
	
	// timers
	reg [31:0] sCounter = 0, bCounter = 1, counter = 0, timerCounter = 8000000, delay_time = 0, gCounter = 1;
	// sCounter for refresh cylce of the 7-segs
	// counter for the game timer
	// bCounter for the 7-seg blink stage when the game is lost
	// timer counter for the cycle speed when the guess sequence is being assinged
	
	// array to hold the sequence order of the game
	// assumes the user wont get past level 16
	integer i[0:15];
	
	// register for the output sequence of the LFSR (Linear Feedback Shift Register)
	// this can hold any value besides 0
	reg [7:0] x_out = 8'b11101001;
	
	// wire to feed the output of the shifting back into the input
	wire linear_feedback;
	
	assign IO_SSEG_COL = 1;		// deactivate the colon displays
	
	// left side of the assign statement changes as soon as the output sequence changes
	assign linear_feedback = !(!(x_out[7] ^ x_out[5]) ^ x_out[1]);
	
	// ********************************** END INITIALIZATION *************************************
	
	// ********************************* TIMER BLOCK ***********************************
	always @(posedge M_CLOCK) begin
	
		bCounter = bCounter + 1;
		// counter for the refresh rate of each of the 7-seg display to out the current level that the user is in
		sCounter = sCounter + 1;
		
		// counter for the greetings menu
		gCounter = gCounter + 1;
		
		// normal state that constantly keeps the 7-seg lit when not in the lost state (s3), menu state (s0), and the lose state that displays (s5)
		if(sCounter >= 32000 && state != s0 && state != s3 && state != s5) begin
			sCounter = 1;		
			case(refreshState)
				s0: begin IO_SSEGD = 4'b1110; IO_SSEG = 8'b01000111; refreshState = s1; end		// L _ _ _
				s1: begin IO_SSEGD = 4'b1101; IO_SSEG = 8'b10111111; refreshState = s2; end		// _ - _ _ 
				s2: begin IO_SSEGD = 4'b1011; IO_SSEG = dig1; refreshState = s3; end					// _ _ # _
				s3: begin IO_SSEGD = 4'b0111; IO_SSEG = dig2; refreshState = s0; end					// _ _ _ #
			endcase
		end
		
		// *********************** STATE MACHINE *************************
		case(state)
		
			// MENU STATE (DEFAULT)
			s0: begin
					IO_LED = 8'b00000000;
					// ************************ GREETS **************************		
					if(sCounter >= 32000) begin
						sCounter = 1;
						if(gCounter >= 5000000) begin
							gCounter = 1;
							scrollCountGreet = scrollCountGreet + 1;
							if(scrollCountGreet >= 14) scrollCountGreet = 0;
						end
						case(refreshState)
							s0: begin IO_SSEGD = 4'b1110; IO_SSEG = fourthBlock; refreshState = s1; end					// X _ _ _
							s1: begin IO_SSEGD = 4'b1101; IO_SSEG = thirdBlock; refreshState = s2; end						// _ X _ _ 
							s2: begin IO_SSEGD = 4'b1011; IO_SSEG = secondBlock; refreshState = s3; end					// _ _ X _
							s3: begin IO_SSEGD = 4'b0111; IO_SSEG = firstBlock; refreshState = s0; end						// _ _ _ X
						endcase					
					end		
					
					// ************************* END GREETS **************************
					
					// check to see if the dipswitch is high, if so proceed to the guessing state
					if(~IO_DSW[7]) begin state = s1; level_state = 1; scrollCountGreet = 0; end
					
			end // END STATE0
			
			// PLAY STATE
			s1: begin 
					counter = counter + 32'b1;
					
					// check to see if the clock counter is greater then the timer counter to go to the next sequence
					// also check if sCount (sequence position) is not greater then the level state
					if(counter >= timerCounter && sCount <= level_state) begin
					
						// the output sequence gets fed back the linear feedback wire and  a new ouput is then generated
						x_out = {x_out[6], x_out[5], x_out[4], x_out[3], x_out[2], x_out[1], x_out[0], linear_feedback};
						
						// check to see if the state is at level one, if so only assign two different sequences (for the start sequences)
						if(level_state == 1) i[sCount] = {x_out[7],x_out[6]};
						
						// if the sequence counter has played all the recently assigned sequences, assign it a new one
						// new seqeunce for each following level
						else if(sCount == level_state) i[sCount] = {x_out[7],x_out[6]};
						
						// last two bits of the output sequence determine which position gets lit up (0-3)
						case(i[sCount])
							0: begin IO_LED = 8'b10000000; end
							1: begin IO_LED = 8'b01000000; end 
							2: begin IO_LED = 8'b00100000; end
							3: begin IO_LED = 8'b00010000; end
							default: IO_LED = 8'b00000000;			
						endcase
						
						// increment the sequence counter to go the next posistion in the array
						sCount = sCount + 1'b1;
						// reset the clock counter for safe guard
						counter = 32'b1;
					end
					
					// the IO_LEDs wil blink off when they have been on for half a second
					if(counter >= (timerCounter / 2)) begin
						IO_LED = 8'b00000000;
						// go to the guessing state one the last sequence has been set
						// and reset all the defaults
						if(sCount >= (1 + level_state)) begin
							counter = 32'b1;
							sCount = 0;
							state = s2;
						end
					end
			end // END STATE1
			
			// GUESS STATE
			s2: begin
					// use the push buttons to detmerine if the correct sequence inputed by the user
					// PB[0] is the left most PB and the PB[3] is the right most push button
					
					// when the user presses the correct PB, the corresponding LED will light up.
					// to prevent continuos feedback from the PB, ive placed a flag to signal that the user
					// has pressed the push button already, so if the user decides to hold down the push button,
					// the game state wont be affected
					
					// if the incorrect PB is pressed, the the game state goes back to 0 and the state machine loops
					// to state 's3' - the losing state
					
					case({~IO_PB[0], ~IO_PB[1], ~IO_PB[2], ~IO_PB[3]})
						1: begin 
							IO_LED = 8'b00010000;
							state = s4;
							if(i[sCount] == 3) begin sCount = sCount + 1'b1; end
							else state = s3;
						end
						
						2: begin
							IO_LED = 8'b00100000;
							state = s4;
							if(i[sCount] == 2) begin sCount = sCount + 1'b1; end
							else state = s3;
						end
						4: begin
							IO_LED = 8'b01000000;
							state = s4;
							if(i[sCount] == 1) begin sCount = sCount + 1'b1; end
							else state = s3;
						end
					
						8: begin
							IO_LED = 8'b10000000;
							state = s4;
							if(i[sCount] == 0) begin sCount = sCount + 1'b1; end
							else state = s3;									
						end
						// default is set to have all the LEDS off and the pb signal set to 0
						default: begin IO_LED = 8'b00000000; end
					endcase
					
					// won if the game state has reached s4 (all proper push buttons were pressed)
					if(sCount >= (1 + level_state)) begin
						// reset the counter back to 0
						counter = 32'b1;
						// shorten the time for the blink rate (to make the next sequence a bit faster/challenging)
						timerCounter = timerCounter - 700000;
						//sequence = 4'b0;
						// the level state gets incremented to so that the proper digit on the 7-seg display gets displayed
						//level_state = level_state + 1;					
						// reset the state back to s1 (sequence state)
						state = s4;
					end				
			end // END STATE2
			
			// LOST STATE
			s3: begin
					// light up all the FPGA LEDs to singal that the game has been lost
					F_LED = 4'b1111;
					// increment the counter to that the lost state is only active for 16000000 click (2 secs)
					counter = counter + 1'b1;
					
					// the 7-seg will staty off for an 8th of a second
					if(bCounter <= 1000000) IO_SSEGD = 4'b1111;
					
					// then flash back on for another 8th of a second
					else if(bCounter >= 1000001 && bCounter <= 2000000) begin
						if(sCounter >= 32000) begin
							sCounter = 1;
							case(refreshState)
								s0: begin IO_SSEGD = 4'b1110; IO_SSEG = 8'b01000111; refreshState = s1; end		// L _ _ _
								s1: begin IO_SSEGD = 4'b1101; IO_SSEG = 8'b10111111; refreshState = s2; end		// _ - _ _ 
								s2: begin IO_SSEGD = 4'b1011; IO_SSEG = dig1; refreshState = s3; end					// _ _ # _
								s3: begin IO_SSEGD = 4'b0111; IO_SSEG = dig2; refreshState = s0; end					// _ _ _ #
							endcase
						end
					end
					// reset the bCounter after a quarter of a second
					else if(bCounter >= 2000001) bCounter = 1;
			
					// check if the counter has reached a total of 2 seconds, and then switch
					// ot the state that will display the 'YOU LOSE' string to the user
					if(counter >= 16000000) state = s5;
					
			end // END STATE3
					
			// DELAY STATE (prevent debouncing of the push buttons)
			s4: begin
					delay_time = delay_time + 1;
					// turn the LED off after a quarter of a second of pressing it
					if(delay_time >= 2000000) IO_LED = 8'b00000000;
					
					// after a half a second of pressing the PB, check if the sequence counter has reached the level state
					// (signaling that the correct sequence was entered), then reset the array counter, increment the level state
					// and set the state back to s0
					if(delay_time >= 4000000) begin
						if(sCount >= (1 + level_state)) begin level_state = level_state + 1; sCount = 0; state = s1; end
						else state = s2;
						delay_time = 0;
					end			
			end // END STATE4
			
			// this state will display to the user that they have lost the game and the start back at
			// state 0 when the string has been fully displayed
			s5: begin
					
					// checks the sCounter to refresh each segment every 32000 ticks, (4ms)
					if(sCounter >= 32000) begin
						sCounter = 1;
						
						// gCounter drives the speed of the text that is being scrolled through
						if(gCounter >= 5000000) begin
							gCounter = 1;
							
							// increment the scroll count lose counter to shift through the each of the characters
							// in each segment
							scrollCountLose = scrollCountLose + 1;
							
							// if the scroll counter is greater than the amount of characters in the string
							// reset all the values back to thier default and go to the next state
							if(scrollCountLose >= 13) begin
								scrollCountLose = 0;
								// reset the timer for the blink rate back to the default 8000000 for 8MHz
								timerCounter = 8000000;
								// counter gets reset back to 0
								counter = 32'b1;
								// all the FPGA LEDs will get turned off
								F_LED = 4'b0000;
								// game state goes back to th e 'menu' state
								state = s0;
								// reser the 7-seg display menu back to 0
								level_state = 1;
								sCount = 0;
							end
						end
						// logic for each of the 7-seg blocks
						case(refreshState)
							s0: begin IO_SSEGD = 4'b1110; IO_SSEG = fourthBlock; refreshState = s1; end					// X _ _ _
							s1: begin IO_SSEGD = 4'b1101; IO_SSEG = thirdBlock; refreshState = s2; end						// _ X _ _ 
							s2: begin IO_SSEGD = 4'b1011; IO_SSEG = secondBlock; refreshState = s3; end					// _ _ X _
							s3: begin IO_SSEGD = 4'b0111; IO_SSEG = firstBlock; refreshState = s0; end						// _ _ _ X
						endcase
					end					
			end // END STATE5
		endcase // ******* END STATE MACHINE ********
	end // *********************************** END TIMER BLOCK ********************************
	
	// *************************** OUTPUT LOGIC FOR LEVEL #'s ************************************
	// seperate always block for the 7-seg combinational output when in the playing state
	always @(level_state) begin
	
		// get the proper digits for the 7-seg displays by dividing the level state by 10 for the
		// digit 2 spaces to the left of the deicmal and mod the level state by 10 to get the digit
		// 1 space to the left of the decimal
		sevSeg3 = level_state / 10;
		sevSeg4 = level_state % 10;

		case(sevSeg3)
			0: dig1 = 8'b11000000;
			1: dig1 = 8'b11111001;
			2: dig1 = 8'b10100100;
			3: dig1 = 8'b10110000;
			4: dig1 = 8'b10011001;
			5: dig1 = 8'b10010010;
			6: dig1 = 8'b10000010;
			7: dig1 = 8'b11111000;
			8: dig1 = 8'b10000000;
			9: dig1 = 8'b10011000;
			default: dig1 = 8'b11000000;
		endcase

		case(sevSeg4)
			0: dig2 = 8'b11000000;
			1: dig2 = 8'b11111001;
			2: dig2 = 8'b10100100;
			3: dig2 = 8'b10110000;
			4: dig2 = 8'b10011001;
			5: dig2 = 8'b10010010;
			6: dig2 = 8'b10000010;
			7: dig2 = 8'b11111000;
			8: dig2 = 8'b10000000;
			9: dig2 = 8'b10011000;
			default: dig2 = 8'b11000000;
		endcase
	end // ***************************** END LEVEL LOGIC **********************************
	
	// ******************************* SCROLLING LOGIC ************************************
	// always block for the combinational output of the 7-seg display when in 'menu' mode
	always @(scrollCountGreet or scrollCountLose) begin
		
		// output depends of the scrolling text depeneds on the state of the game
		case(state)
			
			// state for the greet text
			s0: begin
				case(scrollCountGreet)
					0: begin
						fourthBlock = 8'b11111111;			// blank
						thirdBlock = 8'b11111111;			// blank
						secondBlock = 8'b11111111;			// blank
						firstBlock = 8'b11111111;			// blank
					end
					1: begin
						fourthBlock = 8'b11111111;			// blank
						thirdBlock = 8'b11111111;			// blank
						secondBlock = 8'b11111111;			// blank
						firstBlock = 8'b10010000;			// G
					end
					2: begin
						fourthBlock = 8'b11111111;			// blank
						thirdBlock = 8'b11111111;			// blank
						secondBlock = 8'b10010000;			// G
						firstBlock = 8'b10101111;			// R
					end
					3: begin
						fourthBlock = 8'b11111111;			// blank
						thirdBlock = 8'b10010000;			// G
						secondBlock = 8'b10101111;			// R
						firstBlock = 8'b10000110;			// E
					end					
					4: begin
						fourthBlock = 8'b10010000;			// G
						thirdBlock = 8'b10101111;			// R
						secondBlock = 8'b10000110;			// E
						firstBlock = 8'b10000110;			// E
					end
					5: begin
						fourthBlock = 8'b10101111;			// R
						thirdBlock = 8'b10000110;			// E
						secondBlock = 8'b10000110;			// E
						firstBlock = 8'b10000111;			// T
					end
					6: begin
						fourthBlock = 8'b10000110;			// E
						thirdBlock = 8'b10000110;			// E
						secondBlock = 8'b10000111;			// T
						firstBlock = 8'b11101111;			// I
					end
					7: begin
						fourthBlock = 8'b10000110;			// E
						thirdBlock = 8'b10000111;			// T
						secondBlock = 8'b11101111;			// I
						firstBlock = 8'b10101011;			// N
					end
					8: begin
						fourthBlock = 8'b10000111;			// T
						thirdBlock = 8'b11101111;			// I
						secondBlock = 8'b10101011;			// N
						firstBlock = 8'b10010000;			// G
					end
					9: begin
						fourthBlock = 8'b11101111;			// I
						thirdBlock = 8'b10101011;			// N
						secondBlock = 8'b10010000;			// G
						firstBlock = 8'b10010010;			// S
					end
					10: begin
						fourthBlock = 8'b10101011;			// N
						thirdBlock = 8'b10010000;			// G
						secondBlock = 8'b10010010;			// S
						firstBlock = 8'b11111111;			// blank
					end
					11: begin
						fourthBlock = 8'b10010000;			// G
						thirdBlock = 8'b10010010;			// S
						secondBlock = 8'b11111111;			// blank
						firstBlock = 8'b11111111;			// blank
					end
					12: begin
						fourthBlock = 8'b10010010;			// S
						thirdBlock = 8'b11111111;			// blank
						secondBlock = 8'b11111111;			// blank
						firstBlock = 8'b11111111;			// blank
					end
					13: begin
						fourthBlock = 8'b11111111;			// blank
						thirdBlock = 8'b11111111;			// blank
						secondBlock = 8'b11111111;			// blank
						firstBlock = 8'b11111111;			// blank
					end
					default: begin
						fourthBlock = 8'b11111111;			// blank
						thirdBlock = 8'b11111111;			// blank
						secondBlock = 8'b11111111;			// blank
						firstBlock = 8'b11111111;			// blank
					end
				endcase // end scroll crount greet
			end // end s0
			
			// state for the lose text
			s5: begin
				case(scrollCountLose)
					0: begin
						fourthBlock = 8'b11111111;			// blank
						thirdBlock = 8'b11111111;			// blank
						secondBlock = 8'b11111111;			// blank
						firstBlock = 8'b11111111;			// blank
					end
					1: begin
						fourthBlock = 8'b11111111;			// blank
						thirdBlock = 8'b11111111;			// blank
						secondBlock = 8'b11111111;			// blank
						firstBlock = 8'b10010001;			// Y
					end
					2: begin
						fourthBlock = 8'b11111111;			// blank
						thirdBlock = 8'b11111111;			// blank
						secondBlock = 8'b10010001;			// Y
						firstBlock = 8'b11000000;			// O
					end
					3: begin
						fourthBlock = 8'b11111111;			// blank
						thirdBlock = 8'b10010001;			// Y
						secondBlock = 8'b11000000;			// O
						firstBlock = 8'b11000001;			// U
					end
					4: begin
						fourthBlock = 8'b10010001;			// Y
						thirdBlock = 8'b11000000;			// O
						secondBlock = 8'b11000001;			// U
						firstBlock = 8'b11111111;			// blank
					end
					5: begin
						fourthBlock = 8'b11000000;			// O
						thirdBlock = 8'b11000001;			// U
						secondBlock = 8'b11111111;			// blank
						firstBlock = 8'b11000111;			// L
					end
					6: begin
						fourthBlock = 8'b11000001;			// U
						thirdBlock = 8'b11111111;			// blank
						secondBlock = 8'b11000111;			// L
						firstBlock = 8'b11000000;			// O
					end
					7: begin
						fourthBlock = 8'b11111111;			// blank
						thirdBlock = 8'b11000111;			// L
						secondBlock = 8'b11000000;			// O
						firstBlock = 8'b10010010;			// S
					end
					8: begin
						fourthBlock = 8'b11000111;			// L
						thirdBlock = 8'b11000000;			// O
						secondBlock = 8'b10010010;			// S
						firstBlock = 8'b10000110;			// E
					end
					9: begin
						fourthBlock = 8'b11000000;			// O
						thirdBlock = 8'b10010010;			// S
						secondBlock = 8'b10000110;			// E
						firstBlock = 8'b11111111;			// blank
					end
					10: begin
						fourthBlock = 8'b10010010;			// S
						thirdBlock = 8'b10000110;			// E
						secondBlock = 8'b11111111;			// blank
						firstBlock = 8'b11111111;			// blank
					end
					11: begin
						fourthBlock = 8'b10000110;			// E
						thirdBlock = 8'b11111111;			// blank
						secondBlock = 8'b11111111;			// blank
						firstBlock = 8'b11111111;			// blank
					end
					12: begin
						fourthBlock = 8'b11111111;			// blank
						thirdBlock = 8'b11111111;			// blank
						secondBlock = 8'b11111111;			// blank
						firstBlock = 8'b11111111;			// blank
					end
					default: begin
						fourthBlock = 8'b11111111;			// blank
						thirdBlock = 8'b11111111;			// blank
						secondBlock = 8'b11111111;			// blank
						firstBlock = 8'b11111111;			// blank
					end				
				endcase	// end scrolll count lose case		
			
			end // end s3

		endcase // end case
	end // ******************************* END SCROLL LOGIC **************************************	
endmodule

