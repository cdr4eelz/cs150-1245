`timescale 1ns/1ps
/*--------------------------------------------------------------------------------
-- Company: Digilent
-- Engineer: Arthur Brown
-- 
-- Create Date:    13:01:51 02/15/2013 
-- Project Name:   pmodvga
-- Target Devices: arty
-- Tool versions:  2016.4
-- Additional Comments: 
--    Overall project demo is "Arty-A7-100-Pmod-VGA"
--
-- Copyright Digilent 2017
--
-- *** Translated to Verilog and "simplified" by Erik Rogers (Feb 2025) ***
--------------------------------------------------------------------------------*/

module VGATestPattern (
    input PXL_CLK, // MUST match the other resolution parameters (see end of file)
    output VGA_HS_O,
    output VGA_VS_O,
    output [3:0] VGA_R,
    output [3:0] VGA_G,
    output [3:0] VGA_B
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

    // Moving Box constants
    localparam BOX_WIDTH   = 8; // Supposed to be height & width, but only hight seems to be respected
    localparam BOX_CLK_DIV = 85_000; //1_000_000; // MAX=(2^25 - 1) == 33_554_431
    localparam BOX_X_MAX   = (512 - BOX_WIDTH);
    localparam BOX_Y_MAX   = (FRAME_HEIGHT - BOX_WIDTH);
    localparam BOX_X_MIN   = 0;
    localparam BOX_Y_MIN   = 256;
    localparam [11:0] BOX_X_INIT = 12'h010;
    localparam [11:0] BOX_Y_INIT = 12'h190; //--400

    //wire PXL_CLK; // signal PXL_CLK : std_logic;
    wire active;  // signal active  : std_logic;

    reg [11:0] h_cntr_reg = 0;   // signal h_cntr_reg : std_logic_vector(11 downto 0) := (others =>'0');
    reg [11:0] v_cntr_reg = 0;   // signal v_cntr_reg : std_logic_vector(11 downto 0) := (others =>'0');

    reg h_sync_reg     = !H_POL; // signal h_sync_reg     : std_logic := not(H_POL);
    reg v_sync_reg     = !V_POL; // signal v_sync_reg     : std_logic := not(V_POL);
    reg h_sync_dly_reg = !H_POL; // signal h_sync_dly_reg : std_logic := not(H_POL);
    reg v_sync_dly_reg = !V_POL; // signal v_sync_dly_reg : std_logic :=  not(V_POL);

    reg [3:0] vga_red_reg   = 0; // signal vga_red_reg   : std_logic_vector(3 downto 0) := (others =>'0');
    reg [3:0] vga_green_reg = 0; // signal vga_green_reg : std_logic_vector(3 downto 0) := (others =>'0');
    reg [3:0] vga_blue_reg  = 0; // signal vga_blue_reg  : std_logic_vector(3 downto 0) := (others =>'0');

    wire [3:0] vga_red;          // signal vga_red   : std_logic_vector(3 downto 0);
    wire [3:0] vga_green;        // signal vga_green : std_logic_vector(3 downto 0);
    wire [3:0] vga_blue;         // signal vga_blue  : std_logic_vector(3 downto 0);

    reg [11:0] box_x_reg = BOX_X_INIT; // signal box_x_reg : std_logic_vector(11 downto 0) := BOX_X_INIT;
    reg        box_x_dir = 1;          // signal box_x_dir : std_logic := '1';
    reg [11:0] box_y_reg = BOX_Y_INIT; // signal box_y_reg : std_logic_vector(11 downto 0) := BOX_Y_INIT;
    reg        box_y_dir = 1;          // signal box_y_dir : std_logic := '1';
    reg [24:0] box_cntr_reg = 0;       // signal box_cntr_reg : std_logic_vector(24 downto 0) := (others =>'0');

    wire update_box;   // signal update_box   : std_logic;
    wire pixel_in_box; // signal pixel_in_box : std_logic;
    //begin

    /* CLOCK IS RESPONSIBILTY OF THE ENCOMPASING MODULE
    clk_div_inst : clk_wiz_0
    port map
    (-- Clock in ports
        CLK_IN1 => CLK_I,
        -- Clock out ports
        CLK_OUT1 => PXL_CLK); */

    wire h_LOW, v_LOW, v_8, h_3;
    wire [3:0] val_color;
    assign h_LOW = (h_cntr_reg < 512); // Split left/right regions
    assign v_LOW = (v_cntr_reg < 256); // Split top/bottom regions
    assign v_8 = v_cntr_reg[8], h_3 = h_cntr_reg[3], v_3 = v_cntr_reg[3];
    assign val_color = h_cntr_reg[5:2]; // Take 4-bit color from slice of h_cntr_reg

    /*--------------------------------------------------
    -------         TEST PATTERN LOGIC           -------
    --------------------------------------------------*/
    //vga_red <= h_cntr_reg(5 downto 2) when (active = '1' and ((h_cntr_reg < 512 and v_cntr_reg < 256) and h_cntr_reg(8) = '1')) else
    //          (others=>'1')         when (active = '1' and ((h_cntr_reg < 512 and not(v_cntr_reg < 256)) and not(pixel_in_box = '1'))) else
    //          (others=>'1')         when (active = '1' and ((not(h_cntr_reg < 512) and (v_cntr_reg(8) = '1' and h_cntr_reg(3) = '1')) or
    //                                      (not(h_cntr_reg < 512) and (v_cntr_reg(8) = '0' and v_cntr_reg(3) = '1')))) else (others=>'0');
    assign vga_red   = !active                                      ? 4'b0000 :  // Should be 4'bxxxx but that fails
                       ( h_LOW &&  v_LOW && h_cntr_reg[8])          ? val_color :
                       ( h_LOW && !v_LOW && !pixel_in_box)          ? 4'b1111 :
                       (!h_LOW && ((v_8 && h_3) || (!v_8 && v_3)))  ? 4'b1111 : 4'b0000;
    
    //vga_green <= h_cntr_reg(5 downto 2) when (active = '1' and ((h_cntr_reg < 512 and v_cntr_reg < 256) and h_cntr_reg(7) = '1')) else
    //          (others=>'1')           when (active = '1' and ((h_cntr_reg < 512 and not(v_cntr_reg < 256)) and not(pixel_in_box = '1'))) else 
    //          (others=>'1')           when (active = '1' and ((not(h_cntr_reg < 512) and (v_cntr_reg(8) = '1' and h_cntr_reg(3) = '1')) or
    //                                        (not(h_cntr_reg < 512) and (v_cntr_reg(8) = '0' and v_cntr_reg(3) = '1')))) else (others=>'0');
    assign vga_green = !active                                      ? 4'b0000 :  // Should be 4'bxxxx but that fails
                       ( h_LOW &&  v_LOW && h_cntr_reg[7])          ? val_color :
                       ( h_LOW && !v_LOW && !pixel_in_box)          ? 4'b1111 :
                       (!h_LOW && ((v_8 && h_3) || (!v_8 && v_3)))  ? 4'b1111 : 4'b0000;

    //vga_blue <= h_cntr_reg(5 downto 2) when (active = '1' and ((h_cntr_reg < 512 and v_cntr_reg < 256) and  h_cntr_reg(6) = '1')) else
    //          (others=>'1')          when (active = '1' and ((h_cntr_reg < 512 and not(v_cntr_reg < 256)) and not(pixel_in_box = '1'))) else 
    //          (others=>'1')          when (active = '1' and ((not(h_cntr_reg < 512) and (v_cntr_reg(8) = '1' and h_cntr_reg(3) = '1')) or
    //                                       (not(h_cntr_reg < 512) and (v_cntr_reg(8) = '0' and v_cntr_reg(3) = '1')))) else (others=>'0');
    assign vga_blue  = !active                                      ? 4'b0000 :  // Should be 4'bxxxx but that fails
                       ( h_LOW &&  v_LOW && h_cntr_reg[6])          ? val_color :
                       ( h_LOW && !v_LOW && !pixel_in_box)          ? 4'b1111 :
                       (!h_LOW && ((v_8 && h_3) || (!v_8 && v_3)))  ? 4'b1111 : 4'b0000;


    /*----------------------------------------------------
    -------         MOVING BOX LOGIC                ------
    ----------------------------------------------------*/
    //process (PXL_CLK)  //begin  //  if (rising_edge(PXL_CLK)) then
    always @(posedge PXL_CLK) begin
        if (update_box) begin // if (update_box = '1') then
            if (box_x_dir) begin // if (box_x_dir = '1') then
                box_x_reg <= box_x_reg + 1;
            end else begin // else
                box_x_reg <= box_x_reg - 1;
            end //end if;
            if (box_y_dir) begin // if (box_y_dir = '1') then
                box_y_reg <= box_y_reg + 1;
            end else begin // else
                box_y_reg <= box_y_reg - 1;
            end //end if;
        end //end if;
    end //  end if;  //end process;

    //process (PXL_CLK)  //begin  //  if (rising_edge(PXL_CLK)) then
    always @(posedge PXL_CLK) begin
        if (update_box) begin // if (update_box = '1') then
            //if ((box_x_dir = '1' and (box_x_reg =  BOX_X_MAX - 1)) or (box_x_dir = '0' and (box_x_reg =  BOX_X_MIN + 1))) then
            if   ((box_x_dir       &&  (box_x_reg == BOX_X_MAX - 1)) || (!box_x_dir      &&  (box_x_reg == BOX_X_MIN + 1))) begin
                box_x_dir <= !(box_x_dir); // box_x_dir <= not(box_x_dir);
            end //end if;
            //if ((box_y_dir = '1' and (box_y_reg =  BOX_Y_MAX - 1)) or (box_y_dir = '0' and (box_y_reg =  BOX_Y_MIN + 1))) then
            if   ((box_y_dir       &&  (box_y_reg == BOX_Y_MAX - 1)) || (!box_y_dir      &&  (box_y_reg == BOX_Y_MIN + 1))) begin
                box_y_dir <= !(box_y_dir); // box_y_dir <= not(box_y_dir);
            end //end if;
        end //end if;
    end //  end if;  //end process;

    //process (PXL_CLK)  //begin  //  if (rising_edge(PXL_CLK)) then'
    always @(posedge PXL_CLK) begin
        if (box_cntr_reg == (BOX_CLK_DIV - 1)) begin // if (box_cntr_reg = (BOX_CLK_DIV - 1)) then
            box_cntr_reg <= 0; // box_cntr_reg <= (others=>'0');
        end else begin // else
            box_cntr_reg <= box_cntr_reg + 1;     
        end //end if;
    end //  end if;  //end process;

    // update_box <= '1' when box_cntr_reg = (BOX_CLK_DIV - 1) else '0';
    assign update_box = (box_cntr_reg == (BOX_CLK_DIV - 1));
    // pixel_in_box <= '1' when (((h_cntr_reg >= box_x_reg) and (h_cntr_reg < (box_x_reg + BOX_WIDTH))) and
    //                 ((v_cntr_reg >= box_y_reg) and (v_cntr_reg < (box_y_reg + BOX_WIDTH)))) else '0';
    assign pixel_in_box = (((h_cntr_reg >= box_x_reg) && (h_cntr_reg < (box_x_reg + BOX_WIDTH))) &&
                    ((v_cntr_reg >= box_y_reg) && (v_cntr_reg < (box_y_reg + BOX_WIDTH))));

    /*----------------------------------------------------
    -------         SYNC GENERATION                 ------
    ----------------------------------------------------*/

    //process (PXL_CLK)  //begin  //  if (rising_edge(PXL_CLK)) then
    always @(posedge PXL_CLK) begin
        if (h_cntr_reg == (H_MAX - 1)) begin // if (h_cntr_reg = (H_MAX - 1)) then
            h_cntr_reg <= 0; // h_cntr_reg <= (others =>'0');
        end else begin // else
            h_cntr_reg <= h_cntr_reg + 1;
        end // end if;
    end //  end if;  //end process;
    
    //process (PXL_CLK)  //begin  //  if (rising_edge(PXL_CLK)) then
    always @(posedge PXL_CLK) begin
        //if ((h_cntr_reg =  (H_MAX - 1)) and (v_cntr_reg =  (V_MAX - 1))) then
        if   ((h_cntr_reg == (H_MAX - 1)) &&  (v_cntr_reg == (V_MAX - 1))) begin
            v_cntr_reg <= 0;  // v_cntr_reg <= (others =>'0');
        end else if (h_cntr_reg == (H_MAX - 1)) begin //elsif (h_cntr_reg = (H_MAX - 1)) then
            v_cntr_reg <= v_cntr_reg + 1;
        end //end if;
    end //  end if;  //end process;
    
    //process (PXL_CLK)  //begin  //  if (rising_edge(PXL_CLK)) then
    always @(posedge PXL_CLK) begin
        //if (h_cntr_reg >= (H_FP + FRAME_WIDTH - 1)) and (h_cntr_reg < (H_FP + FRAME_WIDTH + H_PW - 1)) then
        if  ((h_cntr_reg >= (H_FP + FRAME_WIDTH - 1)) &&  (h_cntr_reg < (H_FP + FRAME_WIDTH + H_PW - 1))) begin
            h_sync_reg <= H_POL;
        end else begin // else
            h_sync_reg <= !(H_POL); // h_sync_reg <= not(H_POL);
        end // end if;
    end //  end if;  //end process;
    
    
    //process (PXL_CLK)  //begin  //  if (rising_edge(PXL_CLK)) then
    always @(posedge PXL_CLK) begin
        //if (v_cntr_reg >= (V_FP + FRAME_HEIGHT - 1)) and (v_cntr_reg < (V_FP + FRAME_HEIGHT + V_PW - 1)) then
        if  ((v_cntr_reg >= (V_FP + FRAME_HEIGHT - 1)) &&  (v_cntr_reg < (V_FP + FRAME_HEIGHT + V_PW - 1))) begin
            v_sync_reg <= V_POL;
        end else begin
            v_sync_reg <= !(V_POL); //v_sync_reg <= not(V_POL);
        end // end if;
    end //  end if;  //end process;
    
    
    // active <= '1' when ((h_cntr_reg < FRAME_WIDTH) and (v_cntr_reg < FRAME_HEIGHT)) else '0';
    assign active = ((h_cntr_reg < FRAME_WIDTH) && (v_cntr_reg < FRAME_HEIGHT));

    //process (PXL_CLK)
    //begin
    //  if (rising_edge(PXL_CLK)) then
    always @(posedge PXL_CLK) begin
        v_sync_dly_reg <= v_sync_reg;
        h_sync_dly_reg <= h_sync_reg;
        vga_red_reg   <= vga_red;
        vga_green_reg <= vga_green;
        vga_blue_reg  <= vga_blue;
    end  //  end if;  //end process;

    assign VGA_HS_O = h_sync_dly_reg; // VGA_HS_O <= h_sync_dly_reg;
    assign VGA_VS_O = v_sync_dly_reg; // VGA_VS_O <= v_sync_dly_reg;
    assign VGA_R    = vga_red_reg;    // VGA_R <= vga_red_reg;
    assign VGA_G    = vga_green_reg;  // VGA_G <= vga_green_reg;
    assign VGA_B    = vga_blue_reg;   // VGA_B <= vga_blue_reg;

endmodule // end Behavioral;


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

--***1920x1080@60Hz***-- Requires 148.5 MHz PXL_CLK
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
