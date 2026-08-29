`timescale 1ns/1ps

module COP0150 (
    input               clk, //Clock
    input               ena, //Enable
    input               rst, //Reset

    input               COP0_we, //DataInEnable
    input       [31:0]  COP0_wd, //DataIn
    input       [ 4:0]  COP0_ra, //DataAddress
    output      [31:0]  COP0_rd, //DataOut

    input       [31:0]  intr_pc, //InterruptedPC
    input               intr_handled, //InterruptHandled
    output              intr_request, //InterruptRequest

    input               irq_UARX, //UART0Request
    input               irq_UATX, //UART1Request
    input               irq_pf_frame, //PixelFeederRequest
    input               irq_gp_done //GraphicsProcessorRequest
);

    // Coprocessor "register" addresses:
    localparam  RA_COUNT    = 5'd9,
                RA_COMPARE  = 5'd11,
                RA_STATUS   = 5'd12,
                RA_CAUSE    = 5'd13,
                RA_EPC      = 5'd14;

    // Coprocessor internal "registers":
    reg   [31:0]  count, compare, status, cause, epc;
    reg   [31:0]  dataout_r; // MUX selects value for register address

    // Interrupts generated internal to COP0:
    wire firetimer  = (count == compare);
    wire firertc    = (count == 32'hFFFF_FFFF); //TODO: Pick better compare value???
    // New interrupts both internal and external
    wire [ 5:0] interrupts  = {firetimer, firertc, irq_pf_frame,
                                irq_gp_done, irq_UATX, irq_UARX};

    wire        ie          = status[0];        // Global interrupt enable flag
    wire [ 5:0] im          = status[15:10];    // Enabled interrupts mask
    wire [ 5:0] ip          = cause[15:10];     // Current "active" interrupts
  //wire [ 5:0] next_ip     = ip | (interrupts & im); // Mask new with active "im" mask
    wire [ 5:0] next_ip     = ip | interrupts; // Original was NOT masked by active "im"
    wire [31:0] next_cause  = {cause[31:16], next_ip, cause[9:0]};
    wire [31:0] next_count  = count + 1;

    // Fire CPU interrupt IIF global enabled and ANY enabled & active specific interrupt:
    assign intr_request = ie & |(im & ip);
    assign COP0_rd = dataout_r;


    always@(*) begin
        case (COP0_ra) // Select data out based on reg address
            RA_COUNT:   dataout_r = count;
            RA_COMPARE: dataout_r = compare;
            RA_STATUS:  dataout_r = status;
            RA_CAUSE:   dataout_r = cause;
            RA_EPC:     dataout_r = epc;
            default:    dataout_r = 0; //32'bx if simulation
        endcase
    end

    always@(posedge clk) begin
        if(ena) begin
            if(rst) begin
                epc     <= 32'b0;
                count   <= 32'b0;
                compare <= 32'hFFFF;
                status  <= 32'b0;
                cause   <= 32'b0;
            end else begin
                if (COP0_we) begin // Writing to some COP0 "register"
                    epc     <= epc; // Cannot set EPC (gets set only when interrupt is being handled)
                    count   <= (COP0_ra == RA_COUNT)    ? COP0_wd : next_count;
                    compare <= (COP0_ra == RA_COMPARE)  ? COP0_wd : compare;
                    status  <= (COP0_ra == RA_STATUS)   ? COP0_wd : status;
                    // "cause" is overcomplicated. Plain write is MASKed by "next_ip", a write to
                    //    "compare" (0xB) register (above) ALSO resets timer "cause" bit, and
                    //    finally, "cause" is otherwise updated with "next_ip" via "next_cause".
                    cause   <= (COP0_ra == RA_CAUSE)    ? {COP0_wd[31:16], next_ip & COP0_wd[15:10], COP0_wd[9:0]}
                             : (COP0_ra == RA_COMPARE)  ? {cause[31:16], 1'b0, next_ip[4:0], cause[9:0]}
                             //TODO: Use mask to disable timer, rather than ^^^ 1'b0 inserted (above)
                             : next_cause;
                end else if (intr_handled) begin
                    epc     <= intr_pc;
                    count   <= next_count;
                    compare <= compare;
                    status  <= {status[31:1], 1'b0}; // Disable GLOBAL upon ISR entry
                    cause   <= next_cause;
                end else begin
                    epc     <= epc;
                    count   <= next_count;
                    compare <= compare;
                    status  <= status;
                    cause   <= next_cause;
                end
            end
        end
    end

endmodule
