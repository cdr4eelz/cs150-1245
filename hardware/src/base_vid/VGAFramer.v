`timescale 1ns/1ps
/*--------------------------------------------------------------------------------
-- This test-pattern generator was adapted to provide VGA frame/sync signals.
-- 
-- ORIGINAL BASE FILE came from a DIGILENT PmodVGA example in VHDL --
-- Company: Digilent  Engineer: Arthur Brown  Copyright Digilent 2017
--
-- *** Translated to Verilog and "simplified" by Erik Rogers (Feb 2025) ***
-- *** Morphed into a VGA "framer" which generates VGA H&V SYNCs (2025) ***
--------------------------------------------------------------------------------*/

`default_nettype none

module VGAFramer (
    input  wire clk_pix, // MUST match the other resolution parameters (see end of file)
    input  wire rst_pix,

    input  wire [31:0] video,  // high byte not used
    input  wire video_valid,
    output wire video_ready,

    output wire VGA_HS_O,
    output wire VGA_VS_O,
    output wire [3:0] VGA_R,
    output wire [3:0] VGA_G,
    output wire [3:0] VGA_B
);

    // See the end of this file for settings for other resolutions.
    //   *** BE SURE TO ADJUST THE CLOCK-WIZARD OUTPUT FREQ ***
    //
    // --***800x600@60Hz***--  Requires 40 MHz clock
    parameter FRAME_WIDTH  =  800;
    parameter FRAME_HEIGHT =  600;
    parameter H_FP         =   40; // H front porch width (pixels)
    parameter H_PW         =  128; // H sync pulse width (pixels)
    parameter H_MAX        = 1056; // H total period (pixels)
    parameter V_FP         =    1; // V front porch width (lines)
    parameter V_PW         =    4; // V sync pulse width (lines)
    parameter V_MAX        =  628; // V total period (lines)
    parameter H_POL = 1, V_POL = 1; // H & V polarity

    wire active;

    reg [11:0] h_cntr_reg = 0;
    reg [11:0] v_cntr_reg = 0;

    reg h_sync_reg     = !H_POL;
    reg v_sync_reg     = !V_POL;
    reg h_sync_dly_reg = !H_POL;
    reg v_sync_dly_reg = !V_POL;

    reg [3:0] vga_red_reg   = 0;
    reg [3:0] vga_green_reg = 0;
    reg [3:0] vga_blue_reg  = 0;

    assign video_ready = !rst_pix;
    wire liveActive = video_ready && active;
    //wire [3:0] vga_red   = (liveActive) ? video[ 7: 4] : 4'h0;
    //wire [3:0] vga_green = (liveActive) ? video[15:12] : 4'h0;
    //wire [3:0] vga_blue  = (liveActive) ? video[23:20] : 4'h0;
    wire T_ALL = (h_cntr_reg <= v_cntr_reg);
    wire [3:0] T_R = (T_ALL || (h_cntr_reg %  25 == 0)) ? 4'hF : (v_cntr_reg[3:0]);
    wire [3:0] T_G = (T_ALL || (h_cntr_reg %  50 == 0)) ? 4'hF : (v_cntr_reg[5:2]);
    wire [3:0] T_B = (T_ALL || (h_cntr_reg % 100 == 0)) ? 4'hF : (v_cntr_reg[7:4]);
    wire [3:0] vga_red   = (liveActive) ? T_R : 4'h0;
    wire [3:0] vga_green = (liveActive) ? T_G : 4'h0;
    wire [3:0] vga_blue  = (liveActive) ? T_B : 4'h0;


    //CLOCK IS RESPONSIBILTY OF THE ENCOMPASING MODULE

    /*----------------------------------------------------
    -------         SYNC GENERATION                 ------
    ----------------------------------------------------*/

    always @(posedge clk_pix) begin
        if (rst_pix) begin
            h_cntr_reg <= 0;
            v_cntr_reg <= 0;
            h_sync_reg <= 0;
            v_sync_reg <= 0;
        end else begin
            if (h_cntr_reg == (H_MAX - 1)) begin
                h_cntr_reg <= 0;
            end else begin
                h_cntr_reg <= h_cntr_reg + 1;
            end

            if ((h_cntr_reg == (H_MAX - 1)) &&  (v_cntr_reg == (V_MAX - 1))) begin
                v_cntr_reg <= 0;
            end else if (h_cntr_reg == (H_MAX - 1)) begin
                v_cntr_reg <= v_cntr_reg + 1;
            end

            if ((h_cntr_reg >= (H_FP + FRAME_WIDTH - 1)) &&  (h_cntr_reg < (H_FP + FRAME_WIDTH + H_PW - 1))) begin
                h_sync_reg <= H_POL;
            end else begin
                h_sync_reg <= !(H_POL);
            end

            if  ((v_cntr_reg >= (V_FP + FRAME_HEIGHT - 1)) &&  (v_cntr_reg < (V_FP + FRAME_HEIGHT + V_PW - 1))) begin
                v_sync_reg <= V_POL;
            end else begin
                v_sync_reg <= !(V_POL);
            end
        end
    end
    
    
    assign active = ((h_cntr_reg < FRAME_WIDTH) && (v_cntr_reg < FRAME_HEIGHT));

    always @(posedge clk_pix) begin
        v_sync_dly_reg <= v_sync_reg;
        h_sync_dly_reg <= h_sync_reg;
        vga_red_reg   <= vga_red;
        vga_green_reg <= vga_green;
        vga_blue_reg  <= vga_blue;
    end

    assign VGA_HS_O = h_sync_dly_reg; // VGA_HS_O <= h_sync_dly_reg;
    assign VGA_VS_O = v_sync_dly_reg; // VGA_VS_O <= v_sync_dly_reg;
    assign VGA_R    = vga_red_reg;    // VGA_R <= vga_red_reg;
    assign VGA_G    = vga_green_reg;  // VGA_G <= vga_green_reg;
    assign VGA_B    = vga_blue_reg;   // VGA_B <= vga_blue_reg;

endmodule


/*
--Sync Generation constants

----***640x480@60Hz***--  Requires 25 MHz clock
--constant FRAME_WIDTH : natural := 640;
--constant FRAME_HEIGHT : natural := 480;
--
--constant H_FP : natural := 16; --H front porch width (pixels)
--constant H_PW : natural := 96; --H sync pulse width (pixels)
--constant H_MAX : natural := 800; --H total period (pixels)
--
--constant V_FP : natural := 10; --V front porch width (lines)
--constant V_PW : natural := 2; --V sync pulse width (lines)
--constant V_MAX : natural := 525; --V total period (lines)
--
--constant H_POL : std_logic := '0';
--constant V_POL : std_logic := '0';

----***800x600@60Hz***--  Requires 40 MHz clock
--constant FRAME_WIDTH : natural := 800;
--constant FRAME_HEIGHT : natural := 600;
--
--constant H_FP : natural := 40; --H front porch width (pixels)
--constant H_PW : natural := 128; --H sync pulse width (pixels)
--constant H_MAX : natural := 1056; --H total period (pixels)
--
--constant V_FP : natural := 1; --V front porch width (lines)
--constant V_PW : natural := 4; --V sync pulse width (lines)
--constant V_MAX : natural := 628; --V total period (lines)
--
--constant H_POL : std_logic := '1';
--constant V_POL : std_logic := '1';

----***1280x720@60Hz***-- Requires 74.25 MHz clock
--constant FRAME_WIDTH : natural := 1280;
--constant FRAME_HEIGHT : natural := 720;
--
--constant H_FP : natural := 110; --H front porch width (pixels)
--constant H_PW : natural := 40; --H sync pulse width (pixels)
--constant H_MAX : natural := 1650; --H total period (pixels)
--
--constant V_FP : natural := 5; --V front porch width (lines)
--constant V_PW : natural := 5; --V sync pulse width (lines)
--constant V_MAX : natural := 750; --V total period (lines)
--
--constant H_POL : std_logic := '1';
--constant V_POL : std_logic := '1';

----***1280x1024@60Hz***-- Requires 108 MHz clock
--constant FRAME_WIDTH : natural := 1280;
--constant FRAME_HEIGHT : natural := 1024;
--
--constant H_FP : natural := 48; --H front porch width (pixels)
--constant H_PW : natural := 112; --H sync pulse width (pixels)
--constant H_MAX : natural := 1688; --H total period (pixels)
--
--constant V_FP : natural := 1; --V front porch width (lines)
--constant V_PW : natural := 3; --V sync pulse width (lines)
--constant V_MAX : natural := 1066; --V total period (lines)
--
--constant H_POL : std_logic := '1';
--constant V_POL : std_logic := '1';

--***1920x1080@60Hz***-- Requires 148.5 MHz clk_pix
--constant FRAME_WIDTH : natural := 1920;
--constant FRAME_HEIGHT : natural := 1080;
--
--constant H_FP : natural := 88; --H front porch width (pixels)
--constant H_PW : natural := 44; --H sync pulse width (pixels)
--constant H_MAX : natural := 2200; --H total period (pixels)
--
--constant V_FP : natural := 4; --V front porch width (lines)
--constant V_PW : natural := 5; --V sync pulse width (lines)
--constant V_MAX : natural := 1125; --V total period (lines)
--
--constant H_POL : std_logic := '1';
--constant V_POL : std_logic := '1';
*/
