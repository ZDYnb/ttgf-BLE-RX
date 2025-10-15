//////////////////////////////////////////////////////////////////////////////////
// Engineer: Jacob Louie
// 
// Create Date: 06/18/2024 03:13:25 PM
// Module Name: Matched_Filter
// Description: Timing recovery for Bluetooth_LE and 802.15.4
//////////////////////////////////////////////////////////////////////////////////

module Timing_Recovery_BLE(
    input wire clk,		            // 16MHz
    input wire [1:0] select,        // Select between BLE template and 802.15.4 template (0/else = BLE, 1 = 802.15.4)
	input wire rst,    
	input wire signed [3:0] I_in, 
	input wire signed [3:0] Q_in, 

	// These signals are combined with the matched filter output to produce recovered clock and data
	output wire update_data,	
	input [2:0] sample_point,	//=2         
	input [3:0] e_k_shift,		//=2         
	input [4:0] tau_shift		//=10 or 11  
   );
   
	// Number of I/Q samples held in shift register
    localparam BUFFER_SIZE = 19; 
	// Number of bits in error accumulator
    localparam ERROR_RES = 19;

    integer i;

	// The buffer that holds the last BUFFER_SIZE I/Q samples
    reg signed [3:0] I_k [0:BUFFER_SIZE-1];
    reg signed [3:0] Q_k [0:BUFFER_SIZE-1];
	
	// Intermediate values for calculating timing error
	reg signed [3:0] i_1, q_1, i_2, q_2, i_3, q_3, i_4, q_4;

    reg signed [ERROR_RES-1:0] y1, y2, e_k;
    reg signed [ERROR_RES-1:0] tau_int, tau_int_1;
	reg signed [7:0] tau, tau_1;
	reg signed [3:0] dtau;
	
	reg [3:0] shift_counter;
	wire do_error_calc;

	// Output signals that go to the matched filter to sample data
	assign update_data = (shift_counter == sample_point) ? 1'b1 : 1'b0;
   
    // Save new I/Q samples in buffer
    // Newest data is at the greatest index
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            for (i = 0; i < BUFFER_SIZE; i = i + 1) begin 
                I_k[i] <= 0;
                Q_k[i] <= 0;
            end
        end
        else begin
            for (i = 0; i < BUFFER_SIZE-1; i = i + 1) begin 
                I_k[i] <= I_k[i+1];
                Q_k[i] <= Q_k[i+1];
            end
            I_k[BUFFER_SIZE-1] <= I_in;
            Q_k[BUFFER_SIZE-1] <= Q_in;
        end
    end
	
	// Only calculate eror once per bit/chip to save power
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
			i_1 <= 0;
			q_1 <= 0;
			i_2 <= 0;
			q_2 <= 0;
			i_3 <= 0;
			q_3 <= 0;
			i_4 <= 0;
			q_4 <= 0;
		end
		else begin
			if(do_error_calc) begin
                i_1 <= I_k[4'd8];
                q_1 <= Q_k[4'd8];
                
                i_2 <= I_k[4'd0];
                q_2 <= Q_k[4'd0];
                
                i_3 <= I_k[4'd10];
                q_3 <= Q_k[4'd10];

                i_4 <= I_k[4'd2];
                q_4 <= Q_k[4'd2];  
			end
		end
	end	
	// 802.15.4 Mode (select = 1)
	// 18 17 16 15 ... 10 9 8 7 6 5 4 3 2 1 0
	//                  x | x           x | X
    // 10 = newest I/Q sample
	//  9 = start of symbol at time kT
	//  1 = start of previous symbol at (k-1)T
    // Timing error detector uses points one sample before/after start of current and previous symbol estimate
	// ie, pts 10,8,2 and 0
	
	// BLE Mode (select = 0,2,3)
    // 18 17 16 15 ... 10 9 8 7 6 5 4 3 2 1 0
	//  x  |  x                         x | X
	// 18 = newest I/Q sample
	// 17 = start of symbol at time kT
	//  1 = start of previous symbol at (k-1)T

    // Combinational logic to calculate error
    always @(*) begin                
        y1 = (i_1*i_1 - q_1*q_1)  * (i_2*i_2 - q_2*q_2) + 4*(i_1*q_1*i_2*q_2);
        y2 = (i_3*i_3 - q_3*q_3)  * (i_4*i_4 - q_4*q_4) + 4*(i_3*q_3*i_4*q_4);

        e_k = y1 - y2;
		tau_int = tau_int_1 - (e_k >>> e_k_shift);
        tau = tau_int >>> tau_shift;
	end

	// Store the old estimates of tau
	always @(posedge clk or negedge rst) begin
	    if (!rst) begin
            tau_int_1 <= 0;
            tau_1 <= 0;
            dtau <= 0;
		end
		else begin
			if(do_error_calc) begin
                tau_int_1 <= tau_int;
				tau_1 <= tau;
                dtau <= tau_1 - tau;
			end
		end
	end
	
	// Calculate a new error value when buffer holds current estimate of symbol period
	assign do_error_calc = (select == 1) ? ((shift_counter) == $signed(3'b111 + dtau)):
	                       ((shift_counter) == $signed(4'b1111 + dtau));

	// Increment the counter to shift new samples in until time to calculate error
	always @(posedge clk or negedge rst) begin
		if (!rst) begin
			shift_counter <= 15;
		end
		else begin
			if(do_error_calc) 
				shift_counter <= 0;
			else
				shift_counter <= shift_counter + 1;
		end
	end

endmodule