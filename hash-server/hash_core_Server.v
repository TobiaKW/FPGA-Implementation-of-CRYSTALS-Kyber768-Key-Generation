// keccak hashing server implemented by @xingyf14 
// comments by me, academic purpose.

//note: we use hex notation for all the constants and variables for consistency.

module hash_core_Server(
	input clk, rst,
	//control signals
	input keccak_init,  //trigger hashing core
	input extend,      // Controls whether to continue squeezing from current hashing operation.(SHAKE128/256)
	input patt_bit,    // pattern operation mode
	input eta3_bit,    //use eta3 variant or not(!!the n-like symbol) 
	input [1:0] absorb_ctr_r1, // A 2-bit counter tracking progress through the Keccak absorb phase.
	input [2:0] keccak_ctr,    // A 3-bit counter indicating which stage of Keccak operation (absorbing, squeezing, etc.) is active.
	//1,2,5,6: squeezing
	//others: not squeezing
	//data inputs
	input ififo_wen,           //'1' -> enable input
 	input [31:0] ififo_din,    // 32bit input  
	input ififo_absorb,        
	   //determine whether to hash the input. 
	   //analogy: sponge<=hash, water<=data, 
	   //absorb>>input to hash, squeeze>>hash outputs
	input [1:0] ififo_mode,    //tells the block size of the input stream (7/15/23/31)
	input ififo_last,      //last bit indicate
	//keccak output
	output ififo_empty,    //indicates no input
	output keccak_ready,   //ready to hash
	output keccak_squeeze, //squeezing
	output [31:0] keccak_dout, //output data from hashing core
	//fifo 
	input ofifo_ena,   //enable output
	input ofifo0_req,  //enable read fifo0 (1word)
	input ofifo1_req,  //fifo1
	output [23:0] ofifo0_dout, //fifo0 data output
	output [24:0] ofifo1_dout, //fifo1 data output
	output ofifo0_full,    //full indicator
	output ofifo1_full,
	output ofifo0_empty,   //empty indicator
	output ofifo1_empty,
	//counters
	output reg [5:0] squeeze_ctr,      //count squeezed words
	output reg [7:0] fifo_GENA_ctr     //counter for output grouping
);//ports

wire ififo_req; //wire means signal std_logic
reg ififo_req_r1; //reg means signal INSIDE process
wire [31:0] ififo_dout;
wire ififo_full;

wire absorb;
wire [1:0] mode;
wire last;
reg last_r1;
reg [4:0] pad_ctr;
reg pad_flag;
wire pad_last;
reg extend_r1;
reg keccak_go;
reg keccak_busy;
wire [31:0] keccak_din;

reg ofifo_ena_r1, ofifo_ena_r2;
reg ofifo_wen;
wire [31:0] ofifo_din;
wire [31:0] ofifo_dout;
wire ofifo_empty, ofifo_full;

wire decode_req;
wire [23:0] decode_dout;
wire decode_valid;

wire ofifo_din_valid0, ofifo_din_valid1;
reg fifo_data_parity;
reg [11:0] fifo_data_dropped;
wire ofifo0_wen, ofifo1_wen;
reg [23:0] ofifo0_din;
wire [24:0] ofifo1_din;
reg ofifo1_full_r1;

assign ififo_req = ~(ififo_empty|last&~last_r1|pad_flag|keccak_busy); //defines when enable ififo
//when: ififo empty OR LAST=1 OR padding OR keccak core busy >> '0' >> unable to input from fifo
assign pad_last = pad_ctr == {mode[1:0],3'h7};
//asymmetric, toggle pad_last to tell padding finish and ready to go keccak
//for 7 15 23 31 the last 3 bits are all "111",so there is actually no need to use 5 bit to store pad mode! on
// mode00 >> 8 words, 11 >> 16 words ....

//pad_ctr proc, synchronous
always @(posedge clk) begin
	if(rst)                // 1. rst
		pad_ctr <= 5'h 0;     
	else if(keccak_ready)  //2. reset when keccak ready (i.e. finish padding)
		pad_ctr <= 5'h 0;
	else if(pad_flag)      //3. if pad_flag is 1, increment pad_ctr every clock cycle (note that there will be 1 cycle delay after pad_flag is set)
		pad_ctr <= pad_ctr + 1'h 1;
	else
		pad_ctr <= pad_ctr; //otherwise, keep the same
end

//pad_flag proc, symmetric, flag='1' means start padding, ends padding set back '0'
always @(posedge clk) begin
	if(rst)						//1. rst to 0
		pad_flag <= 1'h 0; 
	else if(last&~last_r1)		//2. set flag='1' when last is toggled from '0' to '1' (rising edge)
		pad_flag <= 1'h 1; 		
	else if(pad_last)			//3. set flag='0' when padding is finished
		pad_flag <= 1'h 0; 
	else
		pad_flag <= pad_flag;  // otherwise keep the same 
end

always @(posedge clk) begin
	last_r1 <= last;		//store the signals of last clock cycle.
	extend_r1 <= extend;
	ififo_req_r1 <= ififo_req;
	ofifo_ena_r1 <= ofifo_ena;		//for output fifo, store 2 clock cycles before.
	ofifo_ena_r2 <= ofifo_ena_r1;
	keccak_go <= pad_last;
end

assign keccak_squeeze = ififo_req_r1 | pad_flag; //keccak core is receiving data from input fifo or padding data in the last clock cycle.
												//means there exist some data to be hashed in the core.
// keccak_busy signal to indicate keccak core is busy.
always @(posedge clk) begin
	if(rst)
		keccak_busy <= 1'h 0;
	else if(pad_last) //when padding is finished, keccak core is busy.
		keccak_busy <= 1'h 1;
	else if(keccak_ready) //when keccak core is ready, keccak core is NOT busy.
		keccak_busy <= 1'h 0;
	else
		keccak_busy <= keccak_busy;//otherwise unchanged
end

//if pad_flag is 1, keccak_din is 0, otherwise keccak_din is the data from input fifo.
assign keccak_din = pad_flag ? 32'h 0 : ififo_dout;


always @(posedge clk) begin
	if(rst)
		squeeze_ctr <= 5'h 0;
	else if(keccak_go || keccak_init || ~extend && extend_r1)
		squeeze_ctr <= 5'h 0;//go, init are external/internal signal, OR extend sig drops(done squeezing extra output)
	else if(keccak_squeeze || extend)  //when squeezing or extending, increment the counter
		//extend is for SHAKE128/256 because they output arbitrary length of data.
		squeeze_ctr <= squeeze_ctr + 1'h 1;//
	else
		squeeze_ctr <= squeeze_ctr;//unchanged
end

assign ofifo_din = keccak_dout; //redirect keccak core output to output fifo

always @(*) case(keccak_ctr)
	3'h 1, 3'h 2, 3'h 5, 3'h 6 : ofifo_wen = ~ofifo_full & ofifo_ena_r2 & keccak_squeeze & ((patt_bit & ~eta3_bit) && ~squeeze_ctr[5] || eta3_bit && squeeze_ctr < 6'h 22 || (~patt_bit&~eta3_bit) && squeeze_ctr < 6'h 2A);
	default : ofifo_wen = 1'h 0;
endcase
//enable ofifo_wen when ALL conditions are met:
//1. keccak_ctr is 1, 2, 5, 6 
//2. output fifo is not full
//3. output is enabled (delayed 2 cycles)
//4. keccak_squeeze is 1 (actively squeezing)
//5. havent exceed the word limit for the current block size

//check if the decoded data is valid: [0,3328]
assign ofifo_din_valid0 = decode_dout[11:0] < 12'h d01;
assign ofifo_din_valid1 = decode_dout[23:12] < 12'h d01;


always @(*) case({ofifo_din_valid0,ofifo_din_valid1,fifo_data_parity})
	3'b 101, 3'b 111 : begin //data valid in lower 12 bits OR both upper and lower.
		ofifo0_din[11:0] = fifo_data_dropped;//put the buffer back to form a pair
		ofifo0_din[23:12] = decode_dout[11:0];
	end
	3'b 011 : begin //only data valid in upper 12 bits
		ofifo0_din[11:0] = fifo_data_dropped;//put the buffer back to form a pair
		ofifo0_din[23:12] = decode_dout[23:12];
	end
	default : begin //no leftover to pair with — pass through decode_dout directly
		ofifo0_din[11: 0] = decode_dout[11:0];
		ofifo0_din[23:12] = decode_dout[23:12];
	end
endcase

assign ofifo1_din = {eta3_bit,decode_dout}; 
// add eta3 bit before the decoded data, total 25bits
assign ofifo0_wen = ~patt_bit&~eta3_bit & decode_valid & ~fifo_GENA_ctr[7] & (ofifo_din_valid0 & ofifo_din_valid1 | (ofifo_din_valid0 ^ ofifo_din_valid1) & fifo_data_parity);
//enable ofifo0_wen when ALL conditions are met.
assign ofifo1_wen = (patt_bit|eta3_bit) & decode_valid & ~ofifo1_full_r1;
//enable ofifo1_wen when ALL conditions are met.
//fifo0 is for 24 bits words, fifo1 is for 25 bits(for pattern and eta3).

always @(posedge clk or negedge rst) begin //tracks the full status of fifo1 //negedge rst is for asynchronous reset.
	if(rst)
		ofifo1_full_r1 <= 1'h 0;
	else if(keccak_ready) //when the before keccak core is finished. refresh.
		ofifo1_full_r1 <= 1'h 0;
	else if(ofifo1_full & eta3_bit)//when fifo1 is full and eta3 bit is 1, set to 1.
		ofifo1_full_r1 <= 1'h 1;
	else
		ofifo1_full_r1 <= ofifo1_full_r1;//otherwise unchanged
end

always @(posedge clk) begin //tracks the parity of the data in fifo0
	if(rst)
		fifo_data_parity <= 1'h 0;
	else if(fifo_GENA_ctr[7] && absorb_ctr_r1 == 2'h 3 && keccak_ready)
		fifo_data_parity <= 1'h 0;
	else if(ofifo_din_valid0 ^ ofifo_din_valid1 && decode_valid && (~patt_bit&~eta3_bit))
		fifo_data_parity <= ~fifo_data_parity;
	else
		fifo_data_parity <= fifo_data_parity;
end
//0 means no leftover, fifo_data_dropped is empty.
//1 means one coefficient is waiting for a partner to make a 24bit output in fifo0

always @(posedge clk) begin
	if(decode_valid & ~patt_bit & ~eta3_bit)
		case({ofifo_din_valid0,ofifo_din_valid1,fifo_data_parity})
		3'b 100 : fifo_data_dropped <= decode_dout[11:0];
		3'b 010, 3'b 111 : fifo_data_dropped <= decode_dout[23:12];
		default : fifo_data_dropped <= fifo_data_dropped;
		endcase		
	else
		fifo_data_dropped <= fifo_data_dropped;
end
//fifo0 needs 24bits to output. so if only one coefficent is valid, it will be buffered in fifo_data_dropped.

always @(posedge clk) begin //fifo_GENA_ctr counts how many coefficient pairs are generated.
	if(rst)//rst reset
		fifo_GENA_ctr <= 6'h 0;
	else if(fifo_GENA_ctr[7] && absorb_ctr_r1 == 2'h 3 && keccak_ready)
		fifo_GENA_ctr <= 6'h 0;//reset when absorb is finished and keccak is ready
	else if(decode_valid && (~patt_bit&~eta3_bit) && ofifo_ena && ~fifo_GENA_ctr[7])
		case({ofifo_din_valid0,ofifo_din_valid1,fifo_data_parity})
		3'b 110, 3'b 111 : fifo_GENA_ctr <= fifo_GENA_ctr + 1'h 1;//both valid >> one pair generated, increment
		3'b 101, 3'b 011 : fifo_GENA_ctr <= fifo_GENA_ctr + 1'h 1;//only one valid >> paired with leftover, increment
		//Note: fifo_data_parity indirectly indicates the leftover status.
		//parity=0 means no leftover, parity=1 means one leftover.(refer to line 202~ block)
		default : fifo_GENA_ctr <= fifo_GENA_ctr;
	endcase
	else 
		fifo_GENA_ctr <= fifo_GENA_ctr;//otherwise unchanged
end
//keccak core
Keccak1600 hash(.CLK(clk),.RESET(rst),.INIT(keccak_init),.SQUEEZE(keccak_squeeze),.EXTEND(extend),.ABSORB(absorb),.GO(keccak_go),.DIN(keccak_din),.DONE(keccak_ready),.RESULT(keccak_dout));
//input fifo
fifo_generator_0 fifo0(.clk(clk),.srst(rst),.din({ififo_mode,ififo_absorb,ififo_last,ififo_din}),.wr_en(ififo_wen),.rd_en(ififo_req),.dout({mode,absorb,last,ififo_dout}),.full(ififo_full),.empty(ififo_empty)); 
//output fifo0
fifo_generator_1 fifo1(.clk(clk),.srst(rst),.din(ofifo0_din),.wr_en(ofifo0_wen),.rd_en(ofifo0_req),.dout(ofifo0_dout),.full(ofifo0_full),.empty(ofifo0_empty));
//output fifo1
fifo_generator_7 fifo2(.clk(clk),.srst(rst),.din(ofifo1_din),.wr_en(ofifo1_wen),.rd_en(ofifo1_req),.dout(ofifo1_dout),.full(ofifo1_full),.empty(ofifo1_empty));
//internal output fifo
fifo_generator_8 fifo8(.clk(clk),.srst(rst),.din(ofifo_din),.wr_en(ofifo_wen),.rd_en(decode_req),.dout(ofifo_dout),.full(ofifo_full),.empty(ofifo_empty));
//decoder
decode_keccak decode(.clk(clk),.rst(rst),.din(ofifo_dout),.fifo_empty(ofifo_empty),.patt_bit(patt_bit),.eta3_bit(eta3_bit),.dout(decode_dout),.req(decode_req),.valid(decode_valid));

//entire pipeline:
//fifo0(input) >> keccak1600 core >> internal fifo8 >> decoder >> validate decode_dout
//default mode (~patt & ~eta3): rejection sampling (< 3329) >> fifo1 >> ofifo0_dout (24-bit paired coefficients)
//pattern/eta3 mode: no rejection >> fifo2 >> ofifo1_dout (25-bit tagged data)

endmodule
