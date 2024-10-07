module spi_controller (
//APB ports
clk, reset, pwrite, paddr, pwdata, prdata, penable, pready,
//SPI ports
sclk_reff, sclk, mosi, miso, cs
);

parameter NO_OF_TXS = 8;
parameter WIDTH = 8;

//APB Interface
input clk, reset, pwrite, penable;
input [WIDTH-1:0] paddr;
input [WIDTH-1:0] pwdata;
output reg pready;
output reg [WIDTH-1:0] prdata;

//SPI Interface
output reg sclk;
output reg mosi;
input sclk_reff,miso;
output reg [2:0] cs;	// 3 slaves

//State machine encoding
parameter S_IDLE = 5'b00001;
parameter S_ADDR = 5'b00010;
parameter S_IDLE_BW_ADDR_DATA = 5'b00100;
parameter S_DATA = 5'b01000;
parameter S_IDLE_WITH_TXS_PENDING = 5'b10000;

//Internal SPI registers
reg [WIDTH-1:0] addr_reg [NO_OF_TXS-1:0];
reg [WIDTH-1:0] data_reg [NO_OF_TXS-1:0];
reg [WIDTH-1:0] ctrl_reg;

reg [4:0] state, next_state;
reg sclk_running_f;
reg [2:0] num_txs_pending;	// store value from ctrl reg[3:1]
reg [2:0] current_tx_index;	// store value from ctrl reg[6:4]
reg [WIDTH-1:0] addr_tx;	
reg [WIDTH-1:0] data_tx;
reg [WIDTH-1:0] data_rx;
int count;

//1. SPI register modelling
always @(posedge clk) begin
	if (reset) begin
		prdata <= 0;
		pready <= 0;
		mosi <= 0;
		cs <= 3'b001;
		state <= S_IDLE;
		next_state <= S_IDLE;
		sclk_running_f <= 0;
		num_txs_pending <= 0;
		current_tx_index <= 0;
		addr_tx <= 0;
		data_tx <= 0;
		data_rx <= 0;
		count <= 0;
		for (int i=0;i<NO_OF_TXS;i++) begin
			addr_reg[i] <= 0;
			data_reg[i] <= 0;	
		end
		ctrl_reg <= 0;
	end
	else begin
		if (penable == 1) begin
			pready <= 1;
			if (pwrite == 1) begin
				if (paddr >= 8'h00 && paddr <= 8'h07) addr_reg[paddr] <= pwdata;
				if (paddr >= 8'h10 && paddr <= 8'h17) data_reg[paddr-8'h10] <= pwdata;
				if (paddr == 8'h20) ctrl_reg <= pwdata;
			end
			else begin
				if (paddr >= 8'h0 && paddr <= 8'h8) prdata <= addr_reg[paddr];
				if (paddr >= 8'h10 && paddr <= 8'h17) prdata <= data_reg[paddr-8'h10];
				if (paddr == 8'h20) prdata <= ctrl_reg;				
			end
		end
		else begin 
			pready <= 0;
		end
	end 
end

// running sclk and implementing gating
assign sclk = sclk_running_f ? sclk_reff : (1'b1);

//2. SPI Operation
always @(posedge clk) begin
	if (reset != 1) begin
		case (state) 
			S_IDLE : begin
				sclk_running_f = 0;
				mosi = 1; 
				if (ctrl_reg[0] == 1) begin
					num_txs_pending <= ctrl_reg[3:1]+1; 
					current_tx_index <= ctrl_reg[6:4];
					addr_tx <= addr_reg[current_tx_index];
					data_tx <= data_reg[current_tx_index];
					next_state <= S_ADDR;
				end
				else begin
					next_state <= S_IDLE;
				end 
			end 
			
			S_ADDR : begin
				sclk_running_f = 1;
				count <= 0;
				mosi <= addr_tx[count];			//write the address
				count <= count+1;
				if (count == 8) begin
					count <= 0;
					next_state <= S_IDLE_BW_ADDR_DATA;
				end
			end
			
			S_IDLE_BW_ADDR_DATA : begin
				sclk_running_f <= 0;
				mosi <= 1;
				count <= count+1;
				if (count == 4) begin
					count <= 0;
					next_state <= S_DATA;
				end
			end
			
			S_DATA : begin
				sclk_running_f <= 1;
				if (addr_tx[WIDTH-1]==1) begin
					mosi <= data_tx[count];		//write the data
					count <= count+1;
				end 
				else begin
					data_rx[count] <= miso;		//read the data
					count <= count+1;
				end

				if (count==8) begin
					current_tx_index <= current_tx_index+1;
					num_txs_pending <= num_txs_pending-1;
					if (num_txs_pending==0) begin
						count <=0;
						ctrl_reg[7] <= 1; 
						ctrl_reg[0] <= 0;
						next_state <= S_IDLE;	
					end
					else begin
						count <= 0;
						next_state <= S_IDLE_WITH_TXS_PENDING;
					end
				end
			end
			
			S_IDLE_WITH_TXS_PENDING : begin
				sclk_running_f <= 1;
				mosi <= 1;
				count <= count+1;
				if (count==4) begin
					count <= 0;
					addr_tx <= addr_reg[current_tx_index];
					data_tx <= data_reg[current_tx_index];
					next_state <= S_ADDR;
				end
			end
			default : next_state <= S_IDLE;
		endcase
	end
end

always @(next_state) begin
	state = next_state;
end

endmodule