//==============================================================================
//	File:		$URL$
//	Version:	$Revision$
//	Author:		Ilia Lebedev (ilial@berkeley.edu)
//	Copyright:	Copyright 2005-2009 UC Berkeley
//==============================================================================

//==============================================================================
//	Section:	License
//==============================================================================
//	Copyright (c) 2005-2009, Regents of the University of California
//	All rights reserved.
//
//	Redistribution and use in source and binary forms, with or without modification,
//	are permitted provided that the following conditions are met:
//
//		- Redistributions of source code must retain the above copyright notice,
//			this list of conditions and the following disclaimer.
//		- Redistributions in binary form must reproduce the above copyright
//			notice, this list of conditions and the following disclaimer
//			in the documentation and/or other materials provided with the
//			distribution.
//		- Neither the name of the University of California, Berkeley nor the
//			names of its contributors may be used to endorse or promote
//			products derived from this software without specific prior
//			written permission.
//
//	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
//	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//	DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
//	ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//	(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
//	ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//	(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//	SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//==============================================================================

//------------------------------------------------------------------------------
//	Module:		Lab3Counter
//	Desc:			This module translates the parsed rotary encoder input into a 
//					4-bit digit to be used by the Lab3Lock module.
//					Note:	this module will output pulses too frequently to be used directly.
//							In fact, the module will output 4 pulses per click of the wheel.
//							You will sove this problem in Lab3Counter.
//	Params:		This module is not parameterized.
//	Inputs:			A:		Raw 'A' input from a rotary encoder.
//					B:		Raw 'B' input from a rotary encoder.
//	Outputs:		Up:		An output
//					Down:		Another output
//	Author:		<a href="mailto:ilial@berkeley.edu">Ilia Lebedev</a>
//	Version:	$Revision$
//------------------------------------------------------------------------------
module	RotaryEncoder(
			//------------------------------------------------------------------
			//	Clock & Reset Inputs
			//------------------------------------------------------------------
			Clock,
			//------------------------------------------------------------------
			
			//------------------------------------------------------------------
			//	Inputs
			//------------------------------------------------------------------
			A,
			B,
			//------------------------------------------------------------------
			
			//------------------------------------------------------------------
			//	Outputs
			//------------------------------------------------------------------
			Up,
			Down
			//------------------------------------------------------------------
	);
	//--------------------------------------------------------------------------
	//	Parameters
	//--------------------------------------------------------------------------
	// <none>
	//--------------------------------------------------------------------------
	
	//--------------------------------------------------------------------------
	//	Clock & Reset Inputs
	//--------------------------------------------------------------------------
	input					Clock;	// System clock
	//--------------------------------------------------------------------------
	
	//--------------------------------------------------------------------------
	//	Inputs
	//--------------------------------------------------------------------------
	input					A, B;
	//--------------------------------------------------------------------------
	
	//--------------------------------------------------------------------------
	//	Outputs
	//--------------------------------------------------------------------------
	output					Up;
	output					Down;
	//--------------------------------------------------------------------------

	//--------------------------------------------------------------------------
	//	Wire Declarations
	//--------------------------------------------------------------------------
	wire	click;
	wire	clockwise;
	
	reg [2:0]	previousA;
	reg [2:0]	previousB;
	//--------------------------------------------------------------------------
	
	//--------------------------------------------------------------------------
	//	Logic
	//--------------------------------------------------------------------------
	always	@	(posedge Clock)	begin
		previousA			<=	{previousA[1:0], A};
		previousB			<=	{previousB[1:0], B};
	end

	assign	click			=	previousA[1] ^ previousA[2] ^ previousB[1] ^ previousB[2];
	assign	clockwise		=	previousA[1] ^ previousB[2];
	
	assign	Up				=	click		&	clockwise;
	assign	Down			=	click		&	~clockwise;

	//--------------------------------------------------------------------------
endmodule
//------------------------------------------------------------------------------
