//============================================================================
//  Arcade: Slap Fight
//
//  Manufaturer: Toaplan
//  Type: Arcade Game
//  Genre: Shooter
//  Orientation: Vertical
//
//  Hardware Description by Anton Gale
//  https://github.com/MiSTer-devel/Arcade-SlapFight_MiSTer
//
//============================================================================
`timescale 1ns/1ps

module slapfight_fpga(
	input clkm_48MHZ,
	input pcb,	
	output [3:0] RED,     	//from fpga core to sv
	output [3:0] GREEN,		//from fpga core to sv
	output [3:0] BLUE,		//from fpga core to sv
	output core_pix_clk,		//from fpga core to sv	
	output H_SYNC,				//from fpga core to sv
	output V_SYNC,				//from fpga core to sv
	output H_BLANK,
	output V_BLANK,
	input RESET_n,				//from sv to core, check implementation
	input pause,
	input [8:0] CONTROLS,	
	input [7:0] DIP1,
	input [7:0] DIP2,
	input [24:0] dn_addr,
	input 		 dn_wr,
	input [7:0]  dn_data,
	output signed [15:0] audio_l, //from jt49_1 & 2
	output signed [15:0] audio_r, //from jt49_1 & 2
	input [15:0] hs_address,
	output [7:0] hs_data_out,
	input [7:0] hs_data_in,
	input hs_write
);

//SLAPFIGHT PIXEL REGISTERS & COUNTERS
reg  [7:0] VPIX,VSCRL_sum_in;
reg [11:0] VCNT;
wire [7:0] VSCRL;
wire [7:0] VPIXSCRL;
reg [11:0] HPIX;
reg  [8:0] HSCRL;
reg  [8:0] HPIXSCRL;

reg clkm_24MHZ;

reg LINE_CLK2;
wire RESET_H_COUNTERS,RESET_V_COUNTERS;

//vertical counter
always @(posedge LINE_CLK) begin
	VCNT <= (!RESET_V_COUNTERS) ? 12'b000000000000 : VCNT+1;
	VPIX <= (IO2_SF) ? 8'b11111111^VCNT[7:0] : VCNT[7:0];
end

wire LINE_CLK=!U1C_Q[2];

wire [3:0] ROM15_out;
ROM15 U8B_ROM15(
    .clk(clkm_48MHZ),
    .addr({VCNT[8:1]}),
    .data({RESET_V_COUNTERS,ROM15_out[2:0]})
);

wire U9E_cout;
wire U8E_cout;

always @(posedge V_SCRL_SEL) VSCRL_sum_in<=(pcb) ? ({Z80A_databus_out[7:4],!IO2_SF,!IO2_SF,!IO2_SF,!IO2_SF}) : Z80A_databus_out; //AY1_IOB_in[7:5]
always @(posedge H_SYNC) LINE_CLK2<=ROM15_out[1];

ttl_7474 #(.BLOCKS(1), .DELAY_RISE(0), .DELAY_FALL(0)) U9H_A(
	.n_pre(PUR),
	.n_clr(INT_ENABLE),
	.d(PUR),
	.clk(!CPU_RAM_SELECT),
	.q(),
	.n_q(Z80M_INT)
);

ttl_74283 #(.WIDTH(4), .DELAY_RISE(0), .DELAY_FALL(0)) U9E(
	.a(VPIX[3:0]),
	.b(VSCRL_sum_in[3:0]),
	.c_in(1'b0),  
	.sum(VSCRL[3:0]),
	.c_out(U9E_cout)
);

ttl_74283 #(.WIDTH(4), .DELAY_RISE(0), .DELAY_FALL(0)) U8E(
	.a(VPIX[7:4]),
	.b(VSCRL_sum_in[7:4]),
	.c_in(U9E_cout),  
	.sum(VSCRL[7:4]),
	.c_out(U8E_cout)
);



//horizontal counter
always @(posedge pixel_clk) begin
	if(!RESET_H_COUNTERS)
	begin
		HPIX <= {3'b000,IO2_SF,2'b00,IO2_SF,2'b00,IO2_SF,IO2_SF,IO2_SF};
	end
	else HPIX <= (!IO2_SF) ? HPIX+1 : HPIX-1 ;
end

wire [3:0] ROM14_out;
ROM14 U2C_ROM14(
    .clk(clkm_48MHZ),
    .addr({IO2_SF,HPIX[8:2]}),
    .data({RESET_H_COUNTERS,ROM14_out[2:0]})
);

wire [3:0] U1J_sum,U2J_sum,U1H_sum;
wire U1J_cout,U2J_cout,U1H_cout,CPU_RAM_SYNC,CPU_RAM_LBUF;
reg IO2_SF;

always @(posedge RESET_n) IO2_SF<=(pcb) ? DIP1[5] : DIP1[6];	

always @(posedge H_SCRL_LO_SEL) begin 
	HSCRL[7:0]<=Z80A_databus_out;		//U3J
end

always @(posedge H_SCRL_HI_SEL) HSCRL[8]<=Z80A_databus_out[0];		//U1G_A
always @(posedge pixel_clk) HPIXSCRL[8:0]<={U1H_sum[0],U2J_sum,U1J_sum}; //U2H & U1C bit 0



wire U7B_D,U7C_C,U4B_D;
assign U7B_D=!(U1C_Q[3]|!IO_4_CPU_RAM);
assign CPU_RAM_SELECT=!(LINE_CLK2|!IO_4_CPU_RAM);
assign CPU_RAM_SYNC=!(U7B_D&CPU_RAM_SELECT);
assign CPU_RAM_LBUF=U1C_Q[3];



wire [3:0] U1C_Q;
wire [3:0] U1C_nQ;

ls175 U1C(
	.nMR(AU_ENABLE),
	.clk(pixel_clk),
	.D({ROM14_out[1],ROM14_out[0],ROM14_out[2],U1H_sum[0]}),
	.Q(U1C_Q),
	.nQ(U1C_nQ)
);


ttl_74283 #(.WIDTH(4), .DELAY_RISE(0), .DELAY_FALL(0)) U1J(
	.a(HPIX[3:0]),
	.b(HSCRL[3:0]),
	.c_in(1'b0),  
	.sum(U1J_sum),
	.c_out(U1J_cout)
);

ttl_74283 #(.WIDTH(4), .DELAY_RISE(0), .DELAY_FALL(0)) U2J(
	.a(HPIX[7:4]),
	.b(HSCRL[7:4]),
	.c_in(U1J_cout),  
	.sum(U2J_sum),
	.c_out(U2J_cout)
);

ttl_74283 #(.WIDTH(4), .DELAY_RISE(0), .DELAY_FALL(0)) U1H(
	.a({3'b000,HPIX[8]}),
	.b({3'b000,HSCRL[8]}),
	.c_in(U2J_cout),  
	.sum(U1H_sum),
	.c_out(U1H_cout)
);

//SLAPFIGHT REGISTERS


reg [7:0] V_SCRL;    //0xE802
reg [7:0] MCU_PORT;  //0xE803

//SLAPFIGHT REGISTERS



wire [10:0] FG_RAMA;
wire FG_RAM_nOE;
wire FG_RAM_nWE;
wire FG_RAM_U4F_nCS;
wire FG_RAM_U4G_nCS;
wire FG_RAM_nWE2,FG_RAM_nWE1;
not U3D_C(FG_RAM_nWE1,FG_RAM_nWE2);
not U3D_D(FG_RAM_nWE,FG_RAM_nWE1);



wire [7:0] FG_PX_D;
wire [8:0] HPIX_LT;

foreground_layer slap_foreground(
	.master_clk(clkm_48MHZ),
	.pixel_clk(pixel_clk),
	.VPIX(VPIX),
	.HPIX(HPIX),
	.SCREEN_FLIP(IO2_SF),
	.ATRRAM(ATRRAM),
	.CHARAM(CHARAM),
	.Z80_WR(Z80_WR),
	.Z80_RD(Z80_RD),
	.CPU_ADDR(Z80A_addrbus),
	.CPU_DIN(Z80A_databus_out),
	.CPU_RAM_SYNC(CPU_RAM_SYNC),
	.dn_addr(dn_addr),
	.dn_data(dn_data),
	.ep3_cs_i(ep3_cs_i),
	.ep4_cs_i(ep4_cs_i),
	.dn_wr(dn_wr),
	.HPIX_LT_out(HPIX_LT),
	.FG_HI_out(FG_HI_out),
	.FG_LO_out(FG_LO_out),
	.pixel_output(FG_PX_D),
	.FG_WAIT(FG_WAIT)
);

background_layer slap_background(
	.master_clk(clkm_48MHZ),
	.pixel_clk(pixel_clk),
	.pcb(pcb),
	.VPIX(VPIX),	
	.VPIXSCRL(VSCRL),
	.HPIXSCRL(HPIXSCRL),
	.SCREEN_FLIP(IO2_SF),
	.BACKGRAM_1(BACKGRAM_1),
	.BACKGRAM_2(BACKGRAM_2),
	.Z80_WR(Z80_WR),
	.Z80_RD(Z80_RD),
	.CPU_RAM_SYNC(CPU_RAM_SYNC),
	.CPU_ADDR(Z80A_addrbus),
	.CPU_DIN(Z80A_databus_out),
	.dn_addr(dn_addr),
	.dn_data(dn_data),
	.ep5_cs_i(ep5_cs_i),
	.ep6_cs_i(ep6_cs_i),
	.ep7_cs_i(ep7_cs_i),
	.ep8_cs_i(ep8_cs_i),
	.dn_wr(dn_wr),
	.BG_HI_out(BG_HI_out),
	.BG_LO_out(BG_LO_out),
	.pixel_output(BG_PX_D),
	.BG_WAIT(BG_WAIT)
);

sprite_layer slap_sprites(
	.master_clk(clkm_48MHZ),
	.pixel_clk(pixel_clk),
	.npixel_clk(clk_6M_1),
	.pixel_clk_lb(clk_6M_3),
	.VPIX(VPIX),
	.HPIX(HPIX),
	.HPIX_LT(HPIX_LT),
	.SCREEN_FLIP(IO2_SF),
	.SPRITE_RAM(SPRITE_RAM),
	.Z80_WR(Z80_WR),
	.Z80_RD(Z80_RD),
	.CPU_ADDR(Z80A_addrbus),
	.CPU_DIN(Z80A_databus_out),
	.CPU_RAM_SYNC(CPU_RAM_SYNC),
	.CPU_RAM_SELECT(CPU_RAM_SELECT),
	.CPU_RAM_LBUF(CPU_RAM_LBUF),
	.dn_addr(dn_addr),
	.dn_data(dn_data),
	.ep9_cs_i(ep9_cs_i),
	.ep10_cs_i(ep10_cs_i),
	.ep11_cs_i(ep11_cs_i),
	.ep12_cs_i(ep12_cs_i),
	.dn_wr(dn_wr),

	.SP_RAMD_out(SP_RAMD_out),
	.pixel_output(SP_PX_D)
);

wire [7:0] FG_HI_out;
wire [7:0] FG_LO_out;
wire [7:0] BG_HI_out;
wire [7:0] BG_LO_out;
wire [7:0] SP_RAMD_out;

//SLAPFIGHT CLOCKS
reg clkf_cpu, maincpuclk_6M, aucpuclk_3M, aucpuclk_3Mb, ayclk_1p5M;
reg clk_6M_1,pixel_clk,clk_6M_3;

//core clock generation logic based on jtframe code
reg [4:0] cencnt =5'd0;

always @(posedge clkm_48MHZ) begin
	cencnt  <= cencnt+5'd1;
end

always @(posedge clkm_48MHZ) begin
	clkm_24MHZ	  	<= cencnt[0]   == 1'd0;
	clkf_cpu			<= cencnt[1:0] == 2'd0;
	maincpuclk_6M  <= cencnt[2:0] == 3'd0;
	clk_6M_1			<= cencnt[2:0] == 3'd0;
	pixel_clk		<= cencnt[2:0] == 3'd2;
	clk_6M_3		 	<= cencnt[2:0] == 3'd4;
   aucpuclk_3M		<= cencnt[3:0] == 4'd0;
   aucpuclk_3Mb  	<= cencnt[3:0] == 4'h8;
   ayclk_1p5M 		<= cencnt[4:0] == 5'd0;		
end

assign core_pix_clk=pixel_clk;

wire PUR = 1'b1;

//Z80 address & databus definitions
wire [15:0] Z80A_addrbus;
wire [7:0] Z80A_databus_in;
wire [7:0] Z80A_databus_out;
wire Z80_MREQ,Z80_WR,Z80_RD,Z80M_IOREQ,Z80M_INT;
wire [7:0] U8M_Z80M_RAM_out;

wire [15:0] AUA,CPU_AUA;
wire [7:0] AUD_in;
wire [7:0] AUD_out;
wire AUIMREQ,AUWR,AURD;
reg Z80_DO_En;

//First Z80 CPU responsible for main game logic, background, foreground & sprites
T80pa Z80A(
	.RESET_n(RESET_n),
	.WAIT_n(wait_n),
	.INT_n(Z80M_INT), //
	.BUSRQ_n(PUR),
	.NMI_n(PUR),
	.CLK(clkf_cpu/*maincpuclk_6M*/), ////clkf_cpu
	.MREQ_n(Z80_MREQ),
	.IORQ_n(Z80M_IOREQ),
	.DI(Z80A_databus_in),
	.DO(Z80A_databus_out),
	.A(Z80A_addrbus),
	.WR_n(Z80_WR),
	.RD_n(Z80_RD)
);

wire RD_BUFFER_FULL_68705,WR_BUFFER_FULL_68705;

//CPU read selection logic
// ******* PRIMARY CPU IC SELECTION LOGIC FOR TILE, SPRITE, SOUND & GAME EXECUTION ********
assign Z80A_databus_in =	(!(SEL_ROM0A)&!Z80_RD) 						? prom_prog1_out:  //&!Z80_RD implied
									(!(SEL_ROM0B)&!Z80_RD)						? prom_prog1b_out:
									(!SEL_ROM1&!Z80_RD) 							? prom_prog2_out: //&!Z80_RD implied
									(!Z80M_IOREQ&!Z80_RD)						? {7'b0000000,LINE_CLK2} :				//VBLANK - Tiger Heli - RD_BUFFER_FULL_68705,WR_BUFFER_FULL_68705 removed from bit 1 & 2
									(!SEL_Z80M_RAM&!Z80_RD)						? U8M_Z80M_RAM_out:
									(!CHARAM&!Z80_RD) 							? FG_LO_out:
									(!ATRRAM&!Z80_RD) 							? FG_HI_out:
									(!BACKGRAM_1&!Z80_RD)				   	? BG_LO_out:
									(!BACKGRAM_2&!Z80_RD)				   	? BG_HI_out:								
									(!SPRITE_RAM&!Z80_RD)	   				? SP_RAMD_out:
									(!AUDIO_CPU_PORT&!AU_RAM_CS&!Z80_RD)	? AUDIO_RAMM_out:
									8'b00000000;

wire FG_WAIT,BG_WAIT;

wire wait_n = !pause&AU_WAIT&((FG_WAIT&BG_WAIT)|pcb); //FG&BG wait when in 'Tiger Heli' mode

wire SEL_EXT,SEL_ROM1,SEL_ROM0B,SEL_ROM0A;
wire AU_RDY;
wire AU_WAIT=AUDIO_CPU_PORT|AU_RDY|!AU_ENABLE; //**** ADDD AU ENABLE


wire AU_RDY2;



//audio wait
ttl_7474 #(.BLOCKS(1), .DELAY_RISE(0), .DELAY_FALL(0)) S2_U9A_A(
	.n_pre(PUR),
	.n_clr(PUR),
	.d(AUDIOM_OK),
	.clk(maincpuclk_6M),
	.q(AU_RDY2),
	.n_q(AU_RDY)
);


ls139x U9P_B(  //sf
	.A(Z80A_addrbus[15:14]),
	.nE(Z80_MREQ),
	.Y({SEL_EXT,SEL_ROM1,SEL_ROM0B,SEL_ROM0A})
);

wire MCU_PORT_WR,V_SCRL_SEL,H_SCRL_HI_SEL,H_SCRL_LO_SEL;
ls139x U9P_A(  //sf
	.A(Z80A_addrbus[1:0]),
	.nE(SEL_MCU_PORT|Z80_WR),
	.Y({MCU_PORT_WR,V_SCRL_SEL,H_SCRL_HI_SEL,H_SCRL_LO_SEL})
);

wire ATRRAM,CHARAM,SEL_MCU_PORT,SPRITE_RAM,BACKGRAM_2,BACKGRAM_1,AUDIO_CPU_PORT,SEL_Z80M_RAM;
ls138x U9K( //sf
  .nE1(SEL_EXT),
  .nE2(SEL_EXT),
  .E3(PUR),
  .A(Z80A_addrbus[13:11]),
  .Y({ATRRAM,CHARAM,SEL_MCU_PORT,SPRITE_RAM,BACKGRAM_2,BACKGRAM_1,AUDIO_CPU_PORT,SEL_Z80M_RAM})
);

wire RESET_68705,IO_C_SPRITE_COLOUR,U9J_Q5,SEL_ROM_BANK_SH,INT_ENABLE,IO_4_CPU_RAM,AU_ENABLE,IO2_SFx;

mux1_8 U9J( //sf
	.nEN(Z80M_IOREQ|Z80_WR),
	.nRST(RESET_n),
	.D(Z80A_addrbus[0]),
	.A(Z80A_addrbus[3:1]),
	.Q({RESET_68705,IO_C_SPRITE_COLOUR,U9J_Q5,SEL_ROM_BANK_SH,INT_ENABLE,IO_4_CPU_RAM,IO2_SFx,AU_ENABLE})
);



//main CPU (Z80A) work RAM - dual port RAM for hi-score logic
dpram_dc #(.widthad_a(11)) U8M_Z80M_RAM //sf
(
	.clock_a(clkm_48MHZ),
	.address_a(Z80A_addrbus[10:0]),
	.data_a(Z80A_databus_out),
	.wren_a(!Z80_WR & !SEL_Z80M_RAM),
	.q_a(U8M_Z80M_RAM_out),
	
	.clock_b(clkm_48MHZ),
	.address_b(hs_address[10:0]),
	.data_b(hs_data_in),
	.wren_b(hs_write),
	.q_b(hs_data_out)
);

//Z80A CPU main program program ROM #1
eprom_0 U8N_A77_00
(
	.ADDR(Z80A_addrbus[13:0]),//tiger heli rom size reduction
	.CLK(clkm_48MHZ),//
	.DATA(prom_prog1_out),//
	.ADDR_DL(dn_addr),
	.CLK_DL(clkm_48MHZ),//
	.DATA_IN(dn_data),
	.CS_DL(ep0_cs_i),
	.WR(dn_wr)
);

eprom_0b U8N_A77_00b //tiger heli ROM addition
(
	.ADDR(Z80A_addrbus[13:0]),//
	.CLK(clkm_48MHZ),//
	.DATA(prom_prog1b_out),//
	.ADDR_DL(dn_addr),
	.CLK_DL(clkm_48MHZ),//
	.DATA_IN(dn_data),
	.CS_DL(ep0b_cs_i),
	.WR(dn_wr)
);

//Z80A CPU main program program ROM #2
eprom_1 U8P_A77_01
(
	.ADDR({SEL_ROM_BANK_SH,Z80A_addrbus[13:0]}),//
	.CLK(clkm_48MHZ),//
	.DATA(prom_prog2_out),//
	.ADDR_DL(dn_addr),
	.CLK_DL(clkm_48MHZ),//
	.DATA_IN(dn_data),
	.CS_DL(ep1_cs_i),
	.WR(dn_wr)
);

wire [7:0] prom_prog1_out;
wire [7:0] prom_prog1b_out; //additional ROM output register for TigerHeli
wire [7:0] prom_prog2_out;
wire [7:0] bg_prom_prog2_out;
wire [7:0] U4N_Z80A_RAM_out;
wire [7:0] U4V_Z80B_RAM_out;

wire CPU_RAM_SELECT;
wire U4Q_BG_WR,U4Q_BG_RD,U4Q_BACKRAM_1,U4Q_BACKRAM_2;
wire [7:0] SF2_U11B_out;

			 
//background

// *************** SOUND CHIPS *****************
wire [7:0] AY_1_databus_out;
wire [7:0] AY_2_databus_out;
wire U4B_B=SEL_MCU_PORT|Z80_RD;
wire U9A_SF_B=RESET_68705&U4B_B;

ttl_7474 #(.BLOCKS(1), .DELAY_RISE(0), .DELAY_FALL(0)) U7A_A(
	.n_pre(1'b0),
	.n_clr(U9A_SF_B),
	.d(1'b0),
	.clk(U4B_B),
	.q(),
	.n_q(RD_BUFFER_FULL_68705)
);

ttl_7474 #(.BLOCKS(1), .DELAY_RISE(0), .DELAY_FALL(0)) U7A_B(
	.n_pre(MCU_PORT_WR),
	.n_clr(U9A_SF_B),
	.d(1'b0),
	.clk(1'b0),
	.q(),
	.n_q(WR_BUFFER_FULL_68705)
);

wire AY12F_sample;
wire [9:0] sound_outF;
wire [9:0] sound_outV;

// *************** SECOND CPU IC SELECTION LOGIC FOR AUDIO *****************
assign AUD_in =					(!AU_ROM_CS&!AURD) ? S2_U12D_AU_A77_02_out :
										(!AU_RAM_CS&!AURD) ? AUDIO_RAM_out :
										(!AU_IO&!AURD&!AY_1_SEL) ? AY_1_databus_out :
										(!AU_IO&!AURD&!AY_2_SEL) ? AY_2_databus_out :										
										8'b00000000;


//Second Z80 CPU responsible for audio
wire AUDIO_CPU_BUSACK;

T80s Z80B(
	.RESET_n(AU_ENABLE),
	.WAIT_n(!pause),
	.INT_n(PUR),
	.BUSRQ_n(AUDIO_CPU_PORT),
	.NMI_n(AUDIO_CPU_NMI),
	.CLK(aucpuclk_3M), 
	.MREQ_n(AUIMREQ),
	.DI(AUD_in),
	.DO(AUD_out),
	.A(CPU_AUA),
	.WR_n(AUWR),
	.RD_n(AURD),
	.BUSAK_n(AUDIO_CPU_BUSACK)
);

wire [7:0] AUDIO_RAM_out;
wire [7:0] AUDIO_RAMM_out;

wire AUDIOM_OK=AUDIO_CPU_PORT|AUDIO_CPU_BUSACK;
assign AUA = (AUDIOM_OK) ? CPU_AUA : Z80A_addrbus;  //when main CPU has control of the bus switch the address lines to the main CPU

//Audio CPU (Z80AU) work RAM - dual port RAM to main CPU (alternative configuration)
dpram_dc #(.widthad_a(11)) S2_U11B //sf
(
	.clock_a(clkm_48MHZ),
	.address_a(CPU_AUA[10:0]),
	.data_a(AUD_out),
	.wren_a(!AUWR & !AU_RAM_CS),
	.q_a(AUDIO_RAM_out),
	
	.clock_b(clkm_48MHZ),
	.address_b(Z80A_addrbus[10:0]),
	.data_b(Z80A_databus_out),
	.wren_b(!AUDIOM_OK & !Z80_WR),
	.q_b(AUDIO_RAMM_out)
);



//AY_1 chip selects
wire AY_1_BDIR=!(AUA[0]|AY_1_SEL);
wire AY_1_BC1= !(AUA[1]|AY_1_SEL);
//AY_2 chip selects
wire AY_2_BDIR=!(AUA[0]|AY_2_SEL);
wire AY_2_BC1=	!(AUA[1]|AY_2_SEL);

//joystick inputs from MiSTer framework
wire m_right  		= CONTROLS[0];
wire m_left   		= CONTROLS[1];
wire m_down   		= CONTROLS[2];
wire m_up     		= CONTROLS[3];
wire m_shoot  		= CONTROLS[4];
wire m_shoot2  	= CONTROLS[5];
wire m_start1p  	= CONTROLS[6];
wire m_start2p  	= CONTROLS[7];
wire m_coin   		= CONTROLS[8];

reg [7:0] AY1_IOA_in,AY1_IOB_in,AY2_IOA_in,AY2_IOB_in;

always @(*) begin
	AY1_IOA_in<=DIP1;
	AY1_IOB_in<=DIP2;
	AY2_IOA_in<=({4'b1111,m_left,m_right,m_down,m_up});
	AY2_IOB_in<=({1'b1,m_coin,m_start2p,m_start1p,2'b11,m_shoot,m_shoot2});
end

jt49_bus #(.COMP(2'b10)) AY_1_S2_U11G(
    .rst_n(AU_ENABLE),
    .clk(clkm_48MHZ),						// signal on positive edge 
    .clk_en(ayclk_1p5M),  					/* synthesis direct_enable = 1 */
    
    .bdir(AY_1_BDIR),						// bus control pins of original chip
    .bc1(AY_1_BC1),
	 .din(AUD_out),
    .sel(1'b1), 								// if sel is low, the clock is divided by 2
    .dout(AY_1_databus_out),
    
	 .sound(sound_outF),  					// combined channel output
    .A(),    									// linearised channel output
    .B(),
    .C(),
    .sample(AY12F_sample),

    .IOA_in(AY1_IOA_in),					//Dip Switch #1 - DIP1
    .IOB_in(AY1_IOB_in)						//Dip Switch #2 - DIP2
);

jt49_bus #(.COMP(2'b10)) AY_2_S2_11J(
    .rst_n(AU_ENABLE),
    .clk(clkm_48MHZ),						// signal on positive edge
    .clk_en(ayclk_1p5M),  					/* synthesis direct_enable = 1 */
    
    .bdir(AY_2_BDIR),	 					// bus control pins of original chip
    .bc1(AY_2_BC1),
	 .din(AUD_out),
    .sel(1'b1), 								// if sel is low, the clock is divided by 2
    .dout(AY_2_databus_out),
    
	 .sound(sound_outV),  					// combined channel output
    .A(),      								// linearised channel output
    .B(),
    .C(),
    .sample(),

    .IOA_in(AY2_IOA_in),					//Control Inputs #1
    .IOB_in(AY2_IOB_in)						//Control Inputs #2

);

//remove DC offset and combine both AY sound chips
//I can't get the filter to work so jtframe_fir is disabled
wire signed [15:0] audio_snd;

jtframe_jt49_filters u_filters(
            .rst    ( !AU_ENABLE    ),
            .clk    ( clkm_48MHZ ),
            .din0   ( sound_outF    ),
            .din1   ( sound_outV    ),
            .sample ( AY12F_sample  ),
            .dout   ( audio_snd     )
        );

assign audio_l = (pause) ? 0 : audio_snd;
assign audio_r = (pause) ? 0 : audio_snd;
		  
//------------------------------------------------- MiSTer data write selector -------------------------------------------------//
//Instantiate MiSTer data write selector to generate write enables for loading ROMs into the FPGA's BRAM
wire ep0_cs_i, ep0b_cs_i, ep1_cs_i, ep2_cs_i, ep3_cs_i, ep4_cs_i, ep5_cs_i, ep6_cs_i, ep7_cs_i, ep8_cs_i,ep9_cs_i,ep10_cs_i,ep11_cs_i,ep12_cs_i,ep13_cs_i,ep_dummy_cs_i,cp1_cs_i,cp2_cs_i,cp3_cs_i;

selector DLSEL
(
	.ioctl_addr(dn_addr),
	.ep0_cs(ep0_cs_i),
	.ep0b_cs(ep0b_cs_i), //addition for Tiger Heli
	.ep1_cs(ep1_cs_i),
	.ep2_cs(ep2_cs_i),
	.ep3_cs(ep3_cs_i),
	.ep4_cs(ep4_cs_i),
	.ep5_cs(ep5_cs_i),
	.ep6_cs(ep6_cs_i),
	.ep7_cs(ep7_cs_i),	
	.ep8_cs(ep8_cs_i),
	.ep9_cs(ep9_cs_i),	
	.ep10_cs(ep10_cs_i),
	.ep11_cs(ep11_cs_i),
	.ep12_cs(ep12_cs_i),
	.ep13_cs(ep13_cs_i),
	.ep_dummy_cs(ep_dummy_cs_i),
	.cp1_cs(cp1_cs_i),
	.cp2_cs(cp2_cs_i),
	.cp3_cs(cp3_cs_i)	
);


wire [15:0] BG_RAMD;
wire [18:0] FG_ROM_ADDR;
wire [7:0]  S2_U12D_AU_A77_02_out;

eprom_2 S2_U12D_AU_A77_02  //Audio Program ROM
(
	.ADDR(CPU_AUA[12:0]),
	.CLK(clkm_48MHZ),
	.DATA(S2_U12D_AU_A77_02_out),

	.ADDR_DL(dn_addr),
	.CLK_DL(clkm_48MHZ),
	.DATA_IN(dn_data),
	.CS_DL(ep2_cs_i),
	.WR(dn_wr)
);

wire S2_U11D_Q7,AU_RAM_CS,AU_IO,S2_U11D_Q4,S2_U11D_Q3,S2_U11D_Q2,S2_U11D_Q1,AU_ROM_CS;
ls138x S2_U11D(
  .nE1(1'b0),
  .nE2(1'b0),
  .E3(PUR),
  .A(AUA[15:13]),
  .Y({S2_U11D_Q7,AU_RAM_CS,AU_IO,S2_U11D_Q4,S2_U11D_Q3,S2_U11D_Q2,S2_U11D_Q1,AU_ROM_CS})
);

wire COMB_AUIMREQ=(AUDIOM_OK|AU_RDY2) ? AUIMREQ:Z80M_IOREQ;

/*
wire AUD_INT_CLK,AUD_INT_SET,S2_U11E_Q5,S2_U11E_Q4,S2_U11E_Q3,S2_U11E_Q2,AY_1_SEL,AY_2_SEL;
ls138x S2_U11E(
  .nE1(COMB_AUIMREQ),
  .nE2(AU_IO),
  .E3(AUA[7]),
  .A(AUA[6:4]),
  .Y({AUD_INT_CLK,AUD_INT_SET,S2_U11E_Q5,S2_U11E_Q4,S2_U11E_Q3,S2_U11E_Q2,AY_1_SEL,AY_2_SEL})
);*/

jt74138 S2_U11E(
	.e1_b(COMB_AUIMREQ), // pin: 4
   .e2_b(AU_IO),			// pin: 5
   .e3(AUA[7]),    		// pin: 6
   .a(AUA[6:4]),     	// pin: 3,2,1
   .y_b({AUD_INT_CLK,AUD_INT_SET,S2_U11E_Q5,S2_U11E_Q4,S2_U11E_Q3,S2_U11E_Q2,AY_1_SEL,AY_2_SEL})   // pin: 7,9,10,11,12,13,14,15
);

reg AUDIO_CPU_NMI;
reg [13:0] U7A_TMR_out;
reg AU_INT_ON=1'b0;
wire nRST_AU=!AU_ENABLE|AU_INT_ON|!RESET_n;

always @(posedge AUD_INT_CLK or negedge RESET_n) AU_INT_ON<=(!RESET_n) ? 1'b1 : 1'b0; //Initialize audio interrupt
always @(posedge aucpuclk_3M or posedge nRST_AU) U7A_TMR_out <= (nRST_AU) ? 0 : U7A_TMR_out+1;

always @(*) AUDIO_CPU_NMI<= (pcb) ? !U7A_TMR_out[12] : !U7A_TMR_out[13]; //change interrupt timing for Tiger Heli board 

//  **** FINAL 12-BIT ANALOGUE OUTPUT ******
//  PRIORTY: FOREGROUND->SPRITES->BACKGROUND

wire [7:0] SP_PX_D;
wire [7:0] BG_PX_D;
reg [7:0] COLOUR_REG;


always @(posedge pixel_clk) begin
	COLOUR_REG <= (FG_PX_D[1:0]) 	? FG_PX_D : 
					  (SP_PX_D[3:0])	? SP_PX_D : BG_PX_D;
end

cprom_1 S2_U12Q  //Red Colour PROM
(
	.ADDR(COLOUR_REG),//
	.CLK(clkm_48MHZ),//
	.DATA(RED),//

	.ADDR_DL(dn_addr),
	.CLK_DL(clkm_48MHZ),//
	.DATA_IN(dn_data),
	.CS_DL(cp1_cs_i),
	.WR(dn_wr)
);

cprom_2 S2_U12P  //Blue Colour PROM
(
	.ADDR(COLOUR_REG),//
	.CLK(clkm_48MHZ),//
	.DATA(BLUE),//

	.ADDR_DL(dn_addr),
	.CLK_DL(clkm_48MHZ),//
	.DATA_IN(dn_data),
	.CS_DL(cp2_cs_i),
	.WR(dn_wr)
);

cprom_3 S2_U12N  //Green Colour PROM
(
	.ADDR(COLOUR_REG),//
	.CLK(clkm_48MHZ),//
	.DATA(GREEN),//

	.ADDR_DL(dn_addr),
	.CLK_DL(clkm_48MHZ),//
	.DATA_IN(dn_data),
	.CS_DL(cp3_cs_i),
	.WR(dn_wr)
);

assign H_SYNC = LINE_CLK;
assign V_SYNC = ROM15_out[0];
assign H_BLANK =  U1C_Q[3] | ((IO2_SF) ? HPIX>283 : HPIX<13) ;  //283/13=852
assign V_BLANK = LINE_CLK2;

endmodule
