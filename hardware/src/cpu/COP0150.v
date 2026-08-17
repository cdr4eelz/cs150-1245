`timescale 1ns/1ps

module COP0150(
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

    input               irq_uart0, //UART0Request
    input               irq_uart1, //UART1Request
    input               irq_pf_frame, //PixelFeederRequest
    input               irq_gp_done //GraphicsProcessorRequest
);

    reg   [31:0]  dataout_r;
    reg   [31:0]  epc;
    reg   [31:0]  count, compare;
    reg   [31:0]  status, cause;
    wire  [31:0]  next_cause;

    wire          firetimer, firertc, ie;
    wire  [5:0]   interrupts, im, ip, next_ip;

    assign COP0_rd      = dataout_r;

    // Fire CPU interrupt IIF global enabled and ANY enabled & active specific interrupt:
    assign intr_request = ie & |(im & ip);

    // Interrupts generated internal to COP0:
    assign firetimer    = (count == compare);
    assign firertc      = (count == 32'hFFFF_FFFF); //TODO: Pick better compare value???
    // Interrupts received as input (from CPU):
    assign interrupts   = {firetimer, firertc, irq_pf_frame,
                            irq_gp_done, irq_uart1, irq_uart0};

    assign ip           = cause[15:10];     // Current "active" interrupt mask
    assign im           = status[15:10];    // Enabled interrupts mask
    assign ie           = status[0];        // Global interrupt enable flag

    //Ignore masked off interrupts but leave if in prior "cause"
    assign next_ip      = ip | (interrupts & im); 
    assign next_cause   = {cause[31:16], next_ip, cause[9:0]};

    always@(*) begin
        case(COP0_ra)
            5'h9:       dataout_r <= count;
            5'hB:       dataout_r <= compare;
            5'hC:       dataout_r <= status;
            5'hD:       dataout_r <= cause;
            5'hE:       dataout_r <= epc;
            default:    dataout_r <= 0; //32'bx if simulation
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
                    epc     <= epc;
                    count   <= (COP0_ra == 5'h9) ? COP0_wd : (count + 1);
                    compare <= (COP0_ra == 5'hB) ? COP0_wd : compare;
                    status  <= (COP0_ra == 5'hC) ? COP0_wd : status;
                    // "cause" is overcomplicated. Plain write is MASKed by "next_ip", a write to
                    //    "compare" (0xB) register (above) ALSO resets timer "cause" bit, and
                    //    finally, "cause" is otherwise updated with "next_ip" here & elsewhere.
                    cause   <= (COP0_ra == 5'hD) ? {COP0_wd[31:16], next_ip & COP0_wd[15:10], COP0_wd[9:0]}
                             : (COP0_ra == 5'hB) ? {cause[31:16], 1'b0, next_ip[4:0], cause[9:0]}
                             :                     next_cause;
                end else if (intr_handled) begin
                    epc     <= intr_pc;
                    count   <= count + 1;
                    compare <= compare;
                    status  <= {status[31:1], 1'b0}; // Disable GLOBAL upon ISR entry
                    cause   <= next_cause;
                end else begin
                    epc     <= epc;
                    count   <= count + 1;
                    compare <= compare;
                    status  <= status;
                    cause   <= next_cause;
                end
            end
        end
    end

endmodule
