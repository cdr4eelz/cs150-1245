module UART(
  input   Clock,
  input   Reset,

  input   [7:0] DataIn,
  input         DataInValid,
  output        DataInReady,

  output  [7:0] DataOut,
  output        DataOutValid,
  input         DataOutReady,

  input         SIn,
  output        SOut
);

  parameter CLOCK_FREQ = 50_000_000;
  parameter BAUD_RATE  =    115_200;

  wire      SOutInt, SInInt;

  IORegister            #(.Width(         1),
                          .Initial(       1'b1))
                    txreg(.Clock(         Clock),
                          .Reset(         1'b0),
                          .Set(           Reset),
                          .Enable(        1'b1),
                          .In(            SOutInt),
                          .Out(           SOut)),

                    rxreg(.Clock(         Clock),
                          .Reset(         1'b0),
                          .Set(           Reset),
                          .Enable(        1'b1),
                          .In(            SIn),
                          .Out(           SInInt));




  UATransmit           #( .CLOCK_FREQ(    CLOCK_FREQ),
                          .BAUD_RATE(     BAUD_RATE))
              uatransmit( .Clock(         Clock),
                          .Reset(         Reset),
                          .DataIn(        DataIn),
                          .DataInValid(   DataInValid),
                          .DataInReady(   DataInReady),
                          .SOut(          SOutInt));

  UAReceive            #( .CLOCK_FREQ(    CLOCK_FREQ),
                          .BAUD_RATE(     BAUD_RATE))
               uareceive( .Clock(         Clock),
                          .Reset(         Reset),
                          .DataOut(       DataOut),
                          .DataOutValid(  DataOutValid),
                          .DataOutReady(  DataOutReady),
                          .SIn(           SInInt));

endmodule
