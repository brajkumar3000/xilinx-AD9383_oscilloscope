/////////////////////////////////////////////////

module top_module(  
         input 	 clk_100mhz,// 100 MHz clock 
			output    Tx,			// tx line
			input     Rx,			// rx line
			output    ADC_CLK,
			input[7:0] ADC_DATA
    );
	 
assign ADC_CLK=clk_100mhz;
localparam [9:0] BYTES_TO_SEND=10'd512;

reg [20:0] tx_clk; 
localparam baud_rate = 230400;   
localparam sys_clk_freq = 100000000;
 
localparam one_baud_cnt = sys_clk_freq / (baud_rate);// clock frequency per bit

reg transmit,wea;
reg [7:0] tx_byte;
wire received, is_receiving, is_transmitting, recv_error;
wire [7:0] rx_byte,data_out,ADC_Dout;

reg [7:0] STATE=IDLE;

localparam [7:0]
			IDLE			=8'd0,
			S1				=8'd1,
			S2				=8'd2,
			S3				=8'd3,
			S4				=8'd4,
			S5				=8'd5,
			WRITE_RAM	=8'd7,
			S0          =8'd8;

reg [8:0] address;

//-- Control signal generation and next states

always @(negedge clk_100mhz) 
begin
	if(received && (rx_byte=="t"))	//Trigger 
		begin
			;		// To do
		end
	if(tx_clk) 
	  begin
       tx_clk = tx_clk - 1'd1;
     end
	case(STATE)
	IDLE:
	begin
	if(received && (rx_byte=="w"))	// write to ram
		begin
			wea=1'd1;	// write enable
			address=9'd0;
			STATE=WRITE_RAM;
		end
	if(received && (rx_byte=="s"))	// read from RAM and send
		begin
			wea=1'd0;	// read enable
			address=9'd0;
			STATE=S0;
		end
	end
//******************************************************	
   S0:
   begin
		tx_byte=data_out;
		STATE=S1;
	end
	S1:
	begin
		if(~is_transmitting)
		begin
			transmit=1'd1;
			STATE=S2;
			tx_clk = one_baud_cnt;// we hold the transmit line high for one_baud_cnt
		end
	end
	S2:
	begin
	if(!tx_clk)
		begin
		transmit=1'd0;// we hold the transmit line high for one_baud_cnt. Then we set it low.
		tx_clk = 10*one_baud_cnt;// we wait for 10 bits (1 start + 8 data + 1 stop)
		STATE=S3;
		end
	end
	S3:
	begin
		if(!tx_clk)// one byte has been sent
			STATE=S4;
	end
	S4:
	begin
		if(address==(BYTES_TO_SEND-1'd1))// all bytes transmitted
			begin
			address=9'd0;
			STATE=IDLE;
			end
		else if (address<(BYTES_TO_SEND-1'd1))
			begin
			address=address+1'd1;
			STATE=S5;// next byte
			end
	end
	S5:
	begin
		STATE=S1;
		tx_byte=data_out;
	end
	//*******************************************
	WRITE_RAM:
	begin
		if(address==(BYTES_TO_SEND-1'd1))
			STATE=IDLE;
		else if(address<(BYTES_TO_SEND-1'd1))
			begin
				address=address+1'd1;
			end
	end
	endcase
end

// Instantiation of uart module
uart my_uart(
		.clk(clk_100mhz),                // The master clock for this module
		.tx(Tx),                         // Outgoing serial line
		.transmit(transmit),             // Signal to transmit
		.tx_byte(tx_byte),               // Byte to transmit
		.is_transmitting(is_transmitting),// Low when transmit line is idle
		.rx(Rx),
		.received(received),              // Indicated that a byte has been received
		.rx_byte(rx_byte),                // Byte received
		.is_receiving(is_receiving),      // Low when receive line is idle
		.recv_error(recv_error)           // Indicates error in receiving packet.
	);     

ram_512_byte my_ram(
  .clka(clk_100mhz), // input clka
  .wea(wea), 			// input [0 : 0] wea
  .addra(address), 	// input [8 : 0] addra
  .dina(ADC_DATA), 	// input [7 : 0] dina
  .douta(data_out) 	// output [7 : 0] douta
);	

endmodule


                                              
