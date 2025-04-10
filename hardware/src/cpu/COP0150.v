
module COP0150(
    input wire              clk, //Clock
    input wire              ena, //Enable
    input wire              rst, //Reset

    input wire              COP0_we, //DataInEnable
    input wire      [31:0]  COP0_wd, //DataIn
    input wire      [ 4:0]  COP0_ra, //DataAddress
    output wire     [31:0]  COP0_rd, //DataOut

    input wire      [31:0]  intr_pc, //InterruptedPC
    input wire              intr_handled, //InterruptHandled
    output wire             intr_request, //InterruptRequest

    input wire              irq_uart0, //UART0Request
    input wire              irq_uart1, //UART1Request
    input wire              irq_pf_frame, //PixelFeederRequest
    input wire              irq_gp_done //GraphicsProcessorRequest
);

    reg   [31:0]  dataout_r;
    reg   [31:0]  epc;
    reg   [31:0]  count, compare;
    reg   [31:0]  status, cause;

    wire          firetimer, firertc, ie;
    wire  [5:0]   interrupts, im, ip, next_ip;

    assign COP0_rd      = dataout_r;
    assign intr_request = ie & |(im & ip);

    assign firetimer    = (count == compare);
    assign firertc      = (count == 32'hFFFF_FFFF);
    //assign interrupts = {firetimer, firertc, 2'b00, irq_uart1, irq_uart0};
    assign interrupts   = {firetimer, firertc, irq_pf_frame, irq_gp_done,
                            irq_uart1, irq_uart0};

    assign ip           = cause[15:10];
    assign im           = status[15:10];
    assign ie           = status[0];

    assign next_ip      = ip | interrupts;

    always@(*) begin
        case(COP0_ra)
            5'hE:       dataout_r <= epc;
            5'h9:       dataout_r <= count;
            5'hB:       dataout_r <= compare;
            5'hC:       dataout_r <= status;
            5'hD:       dataout_r <= cause;
            default:    dataout_r <= 32'bx;
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
                if(COP0_we) begin
                    epc     <= epc;
                    count   <= (COP0_ra == 5'h9) ? COP0_wd : (count + 1);
                    compare <= (COP0_ra == 5'hB) ? COP0_wd : compare;
                    status  <= (COP0_ra == 5'hC) ? COP0_wd : status;
                    cause   <= (COP0_ra == 5'hD) ? {COP0_wd[31:16], next_ip & COP0_wd[15:10], COP0_wd[9:0]}
                             : (COP0_ra == 5'hB) ? {cause[31:16], 1'b0, next_ip[4:0], cause[9:0]}
                             :                       {cause[31:16], next_ip, cause[9:0]};
                end else if(intr_handled) begin
                    epc     <= intr_pc;
                    count   <= count + 1;
                    compare <= compare;
                    status  <= {status[31:1], 1'b0};
                    cause   <= {cause[31:16], next_ip, cause[9:0]};
                end else begin
                    epc     <= epc;
                    count   <= count + 1;
                    compare <= compare;
                    status  <= status;
                    cause   <= {cause[31:16], next_ip, cause[9:0]};
                end
            end
        end
    end

endmodule
