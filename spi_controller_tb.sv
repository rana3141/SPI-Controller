// SPI Controller testbench

module tb;

parameter NO_OF_TXS = 8;
parameter WIDTH = 8;

//APB Interface
reg clk, preset, pwrite, penable;
reg [WIDTH-1:0] paddr;
reg [WIDTH-1:0] pwdata;
wire pready;
wire [WIDTH-1:0] prdata;

//SPI Interface
wire sclk;
wire mosi;
reg sclk_reff,miso;
wire [2:0] cs;	// 3 slaves

spi_controller dut(//APB ports
				.clk(clk), 
				.reset(preset), 
				.pwrite(pwrite), 
				.paddr(paddr), 
				.pwdata(pwdata), 
				.prdata(prdata), 
				.penable(penable), 
				.pready(pready),
				
				//SPI ports
				.sclk_reff(sclk_reff), 
				.sclk(sclk), 
				.mosi(mosi), 
				.miso(miso), 
				.cs(cs)
				);

always begin
	clk = 0; #5;
	clk = 1; #5;
end

always begin
	sclk_reff = 0; #2;
	sclk_reff = 1; #2;
end

initial begin
	preset = 1;
	reset();
	@(posedge clk);
	@(posedge clk);
	preset = 0;
	@(posedge clk);
	
	//Address registers
	for (int i=0;i<NO_OF_TXS;i++) begin
		write(i, i+8'hd3);		//0-d3//1-d4//2-d5//3-d6 //d -> MSB bit=1-> write operation
	end

	//Data Registers
	for (int i=0;i<NO_OF_TXS;i++) begin
		write(i+8'h10,i+8'h12);	//10-12//11-13//12-14
	end

	//Control register
	write(8'h20,{8'h0f});
	#1000;
end

task reset();
	pwrite = 0;
	penable = 0;
	paddr = 0;
	pwdata = 0;
	miso = 0;
	sclk_reff = 0;
endtask

task write(input reg [WIDTH-1:0] addr, input reg [WIFTH-1:0] data);
	@(posedge clk);
	pwrite = 1;
	paddr = addr;
	pwdata = data;
	penable = 1;
	wait (pready==1);
	@(posedge clk);
	reset();
endtask


initial begin
   $dumpfile("spi.vcd");
   $dumpvars(0, tb);
end

endmodule