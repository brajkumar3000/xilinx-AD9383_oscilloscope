`timescale 1ns / 1ps

 module uart(
    input clk,                  // The 100 MHz master clock for this module
    output tx,                  // Outgoing serial line
    input rx,                   // Incoming serial line
	 input transmit,             // Assert to begin transmission
    input [7:0] tx_byte,        // Byte to transmit
	 output received,            // Indicates that a byte has been received
    output [7:0] rx_byte,       // Byte received
    output wire is_receiving,   // Low when receive line is idle.
	 output wire recv_error,     // Indicates error in receiving packet.
    output wire is_transmitting // Low when transmit line is idle.
);

//  localparam baud_rate = 115200;
	 localparam baud_rate = 230400;    
    localparam sys_clk_freq = 100000000;
    localparam one_baud_cnt = sys_clk_freq / (baud_rate);

//** SYMBOLIC STATE DECLARATIONS ******************************
    localparam [2:0]     
        RX_IDLE             = 3'd0, 
        RX_CHECK_START      = 3'd1, 
        RX_SAMPLE_BITS      = 3'd2,
        RX_READ_BITS        = 3'd3,      
        RX_CHECK_STOP       = 3'd4, 
        RX_DELAY_RESTART    = 3'd5,
        RX_ERROR            = 3'd6,      
        RX_RECEIVED         = 3'd7; 
    localparam [1:0]     
        TX_IDLE             = 2'd0,
        TX_SENDING          = 2'd1,
        TX_DELAY_RESTART    = 2'd2,
        TX_RECOVER          = 2'd3;
  
  
//** SIGNAL DECLARATIONS **************************************
	 
	 reg [15:0] rx_clk; //
    reg [15:0] tx_clk; //
	 reg [2:0] recv_state = RX_IDLE;
    reg [3:0] rx_bits_remaining;
    reg [7:0] rx_data;
	 
    reg tx_out = 1'b1;
    reg [1:0] tx_state = TX_IDLE;
    reg [3:0] tx_bits_remaining;
    reg [7:0] tx_data;
    reg reg_transmitting=1'b0; 

//** ASSIGN STATEMENTS ****************************************
	 assign received = (recv_state == RX_RECEIVED);
    assign recv_error = (recv_state == RX_ERROR);
    assign is_receiving = (recv_state != RX_IDLE);
    assign rx_byte = rx_data;

    assign tx = tx_out;
	 assign is_transmitting=(tx_state!=TX_IDLE);
    
//** Body *****************************************************

    always @(posedge clk) 
	 begin
        // Countdown timers for the receiving and transmitting
        // state machines are decremented.
        if(rx_clk) 
		  begin
            rx_clk = rx_clk - 1'd1;
        end
		  
        if(tx_clk) 
		  begin
            tx_clk = tx_clk - 1'd1;
        end
//** Receive state machine ************************************
        case (recv_state)
            RX_IDLE: 
				begin
                // A low pulse on the receive line indicates the
                // start of data.
                if (!rx) 
					 begin
                    // Wait 1/2 of the bit period
                    rx_clk=one_baud_cnt/2; // 
						  //Original rx_clk = one_baud_cnt / 2;
	                 recv_state = RX_CHECK_START;
                end
            end
				RX_CHECK_START: 
				begin
                if (!rx_clk) 
					 begin
                    // Check the pulse is still there
                    if (!rx) 
						  begin
                        // Pulse still there - good
                        //  
                        rx_clk = one_baud_cnt; 
                        rx_bits_remaining = 8;  
                        recv_state = RX_READ_BITS;
                     end else begin
                        // Pulse did not last -
                        // not a valid transmission.
                        recv_state = RX_ERROR;
                    end
                end
            end

			   RX_READ_BITS: 
				begin
                if (!rx_clk) 
					 begin
                    // Start to read the bits at the middle 
                    if (rx) 
						  begin
                        rx_data = {1'd1, rx_data[7:1]};
                    end 
						  else 
						  begin
                        rx_data = {1'd0, rx_data[7:1]};
                    end
                    
                    rx_clk = one_baud_cnt;// Next reading should be at the middle
                    rx_bits_remaining = rx_bits_remaining - 1'd1;
                    if(rx_bits_remaining)
						  begin
                        recv_state = RX_READ_BITS;
                    end 
						  else 
						  begin
                        recv_state = RX_CHECK_STOP;
                        rx_clk = one_baud_cnt;
                    end
                end
            end
				RX_CHECK_STOP: 
				begin
                if (!rx_clk) 
					 begin
                    // Should resume half-way through the stop bit
                    // This should be high - if not, reject the
                    // transmission and signal an error.
                    recv_state = rx ? RX_RECEIVED : RX_ERROR;
                end
            end
				RX_ERROR: 
				begin
                // There was an error receiving.
                // Raises the recv_error flag for one clock
                // cycle while in this state and then waits
                // 1 byte periods before accepting another
                // transmission.
                rx_clk = 8 * one_baud_cnt;
                recv_state = RX_DELAY_RESTART;
            end
				RX_DELAY_RESTART: 
				begin
                // Waits a set number of cycles before accepting
                // another transmission.
                recv_state = rx_clk ? RX_DELAY_RESTART : RX_IDLE;
            end
				RX_RECEIVED: begin
                // Successfully received a byte.
                // Raises the received flag for one clock
                // cycle while in this state.
                recv_state = RX_IDLE;
            end
		  endcase
		  
           
//** Transmit state machine ***********************************

        case (tx_state)
            TX_IDLE: 
				begin
                if (transmit) 
					 begin
                    tx_data = tx_byte;
                    tx_clk = one_baud_cnt;
                    tx_out = 0;	// start bit
                    tx_bits_remaining = 8;
                    tx_state = TX_SENDING;
						  reg_transmitting =1;// New
                end
            end
            
            TX_SENDING: 
				begin
                if (!tx_clk) 
					 begin
                    if (tx_bits_remaining) 
								begin
                        tx_bits_remaining = tx_bits_remaining - 1'd1;
                        // order of transmitting bits is LSB first: MSB last
								tx_out = tx_data[0];	
                        tx_data = {1'b0, tx_data[7:1]};// shifting to right
                        tx_clk = one_baud_cnt;
                        tx_state = TX_SENDING;
								end 
							else 
								begin
                        // Set delay to send out 2 stop bits.
                        tx_out = 1;
                        // 
								tx_clk = 2 * one_baud_cnt; 
                        tx_state = TX_DELAY_RESTART;
								end
                end
            end
            
            TX_DELAY_RESTART: 
				begin
                // Wait until tx_countdown reaches the end before
                // we send another transmission. This covers the
                // "stop bit" delay.
                tx_state = tx_clk ? TX_DELAY_RESTART : TX_RECOVER;// TX_IDLE;
            end
            
            TX_RECOVER: begin
                // I have changed this from original: biju
                tx_state = TX_IDLE;
            end
            
        endcase
    end

endmodule
