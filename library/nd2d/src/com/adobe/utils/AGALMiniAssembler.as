/*
Copyright (c) 2011, Adobe Systems Incorporated
All rights reserved.

Redistribution and use in source and binary forms, with or without 
modification, are permitted provided that the following conditions are
met:

* Redistributions of source code must retain the above copyright notice, 
this list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the 
documentation and/or other materials provided with the distribution.

* Neither the name of Adobe Systems Incorporated nor the names of its 
contributors may be used to endorse or promote products derived from 
this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR 
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
package com.adobe.utils
{
	// ===========================================================================
	//	Imports
	// ---------------------------------------------------------------------------
	//import flash.display3D.*;
	import flash.utils.*;
	
	// ===========================================================================
	//	Class
	// ---------------------------------------------------------------------------
	public class AGALMiniAssembler
	{
		// ======================================================================
		//	Constants
		// ----------------------------------------------------------------------
		protected static const USE_NEW_SYNTAX:Boolean			= false;
		
		protected static const REGEXP_OUTER_SPACES:RegExp		= /^\s+|\s+$/g;
		
		// ======================================================================
		//	Properties
		// ----------------------------------------------------------------------
		// AGAL bytes and error buffer 
		protected var _agalcode:ByteArray							= null;
		protected var _error:String								= "";
		
		protected var debugEnabled:Boolean						= false;
		
		protected static var initialized:Boolean					= false;
		public var verbose:Boolean								= false;
		
		// ======================================================================
		//	Getters
		// ----------------------------------------------------------------------
		public function get error():String						{ return _error; }
		public function get agalcode():ByteArray				{ return _agalcode; }
		
		// ======================================================================
		//	Constructor
		// ----------------------------------------------------------------------
		public function AGALMiniAssembler( debugging:Boolean = false ):void
		{
			debugEnabled = debugging;
			if ( !initialized )
				init();
		}
		// ======================================================================
		//	Methods
		// ----------------------------------------------------------------------
		public function assemble( mode:String, source:String ):ByteArray
		{
			var start:uint = getTimer();
			
			_agalcode							= new ByteArray();
			_error = "";
			
			var isFrag:Boolean = false;
			
			if ( mode == FRAGMENT )
				isFrag = true;
			else if ( mode != VERTEX )
				_error = 'ERROR: mode needs to be "' + FRAGMENT + '" or "' + VERTEX + '" but is "' + mode + '".';
			
			agalcode.endian = Endian.LITTLE_ENDIAN;
			agalcode.writeByte( 0xa0 );				// tag version
			agalcode.writeUnsignedInt( 0x1 );		// AGAL version, big endian, bit pattern will be 0x01000000
			agalcode.writeByte( 0xa1 );				// tag program id
			agalcode.writeByte( isFrag ? 1 : 0 );	// vertex or fragment
			
			var lines:Array = source.replace( /[\f\n\r\v]+/g, "\n" ).split( "\n" );
			var nest:int = 0;
			var nops:int = 0;
			var i:int;
			var lng:int = lines.length;
			
			for ( i = 0; i < lng && _error == ""; i++ )
			{
				var line:String = new String( lines[i] );
				line = line.replace( REGEXP_OUTER_SPACES, "" );
				
				// remove comments
				var startcomment:int = line.search( "//" );
				if ( startcomment != -1 )
					line = line.slice( 0, startcomment );
				
				// grab options
				var optsi:int = line.search( /<.*>/g );
				var opts:Array;
				if ( optsi != -1 )
				{
					opts = line.slice( optsi ).match( /([\w\.\-\+]+)/gi );
					line = line.slice( 0, optsi );
				}
				
				// find opcode
				var opCode:Array = line.match( /^\w{3}/ig );
				if ( !opCode ) 
				{
					if ( line.length >= 3 )
						trace( "warning: bad line "+i+": "+lines[i] );
					continue;
				}
				var opFound:OpCode = OPMAP[ opCode[0] ];
				
				// if debug is enabled, output the opcodes
				if ( debugEnabled )
					trace( opFound );
				
				if ( opFound == null )
				{
					if ( line.length >= 3 )
						trace( "warning: bad line "+i+": "+lines[i] );
					continue;
				}
				
				line = line.slice( line.search( opFound.name ) + opFound.name.length );
				
				// nesting check
				if ( opFound.flags & OP_DEC_NEST )
				{
					nest--;
					if ( nest < 0 )
					{
						_error = "error: conditional closes without open.";
						break;
					}
				}
				if ( opFound.flags & OP_INC_NEST )
				{
					nest++;
					if ( nest > MAX_NESTING )
					{
						_error = "error: nesting to deep, maximum allowed is "+MAX_NESTING+".";
						break;
					}
				}
				if ( ( opFound.flags & OP_FRAG_ONLY ) && !isFrag )
				{
					_error = "error: opcode is only allowed in fragment programs.";
					break;
				}
				if ( verbose )
					trace( "emit opcode=" + opFound );
				
				agalcode.writeUnsignedInt( opFound.emitCode );
				nops++;
				
				if ( nops > MAX_OPCODES )
				{
					_error = "error: too many opcodes. maximum is "+MAX_OPCODES+".";
					break;
				}
				
				// get operands, use regexp
				var regs:Array;
				if ( USE_NEW_SYNTAX )
					regs = line.match( /vc\[([vif][acost]?)(\d*)?(\.[xyzw](\+\d{1,3})?)?\](\.[xyzw]{1,4})?|([vif][acost]?)(\d*)?(\.[xyzw]{1,4})?/gi );
				else
					regs = line.match( /vc\[([vof][actps]?)(\d*)?(\.[xyzw](\+\d{1,3})?)?\](\.[xyzw]{1,4})?|([vof][actps]?)(\d*)?(\.[xyzw]{1,4})?/gi );
				
				if ( !regs || regs.length != opFound.numRegister )
				{
					_error = "error: wrong number of operands. found "+regs.length+" but expected "+opFound.numRegister+".";
					break;					
				}
				
				var badreg:Boolean	= false;
				var pad:uint		= 64 + 64 + 32;
				var regLength:uint	= regs.length;
				
				for ( var j:int = 0; j < regLength; j++ )
				{
					var isRelative:Boolean = false;
					var relreg:Array = regs[ j ].match( /\[.*\]/ig );
					if ( relreg && relreg.length > 0 )
					{
						regs[ j ] = regs[ j ].replace( relreg[ 0 ], "0" );
						
						if ( verbose )
							trace( "IS REL" );
						isRelative = true;
					}
					
					var res:Array = regs[j].match( /^\b[A-Za-z]{1,2}/ig );
					if ( !res ) 
					{
						_error = "error: could not parse operand "+j+" ("+regs[j]+").";
						badreg = true;
						break;
					}
					var regFound:Register = REGMAP[ res[ 0 ] ];
					
					// if debug is enabled, output the registers
					if ( debugEnabled )
						trace( regFound );
					
					if ( regFound == null )
					{
						_error = "error: could not parse operand "+j+" ("+regs[j]+").";
						badreg = true;
						break;
					}
					
					if ( isFrag )
					{
						if ( !( regFound.flags & REG_FRAG ) )
						{
							_error = "error: register operand "+j+" ("+regs[j]+") only allowed in vertex programs.";
							badreg = true;
							break;
						}
						if ( isRelative )
						{
							_error = "error: register operand "+j+" ("+regs[j]+") relative adressing not allowed in fragment programs.";
							badreg = true;
							break;
						}			
					}
					else
					{
						if ( !( regFound.flags & REG_VERT ) )
						{
							_error = "error: register operand "+j+" ("+regs[j]+") only allowed in fragment programs.";
							badreg = true;
							break;
						}
					}
					
					regs[j] = regs[j].slice( regs[j].search( regFound.name ) + regFound.name.length );
					//trace( "REGNUM: " +regs[j] );
					var idxmatch:Array = isRelative ? relreg[0].match( /\d+/ ) : regs[j].match( /\d+/ );
					var regidx:uint = 0;
					
					if ( idxmatch )
						regidx = uint( idxmatch[0] );
					
					if ( regFound.range < regidx )
					{
						_error = "error: register operand "+j+" ("+regs[j]+") index exceeds limit of "+(regFound.range+1)+".";
						badreg = true;
						break;
					}
					
					var regmask:uint		= 0;
					var maskmatch:Array		= regs[j].match( /(\.[xyzw]{1,4})/ );
					var isDest:Boolean		= ( j == 0 && !( opFound.flags & OP_NO_DEST ) );
					var isSampler:Boolean	= ( j == 2 && ( opFound.flags & OP_SPECIAL_TEX ) );
					var reltype:uint		= 0;
					var relsel:uint			= 0;
					var reloffset:int		= 0;
					
					if ( isDest && isRelative )
					{
						_error = "error: relative can not be destination";	
						badreg = true; 
						break;								
					}
					
					if ( maskmatch )
					{
						regmask = 0;
						var cv:uint; 
						var maskLength:uint = maskmatch[0].length;
						for ( var k:int = 1; k < maskLength; k++ )
						{
							cv = maskmatch[0].charCodeAt(k) - "x".charCodeAt(0);
							if ( cv > 2 )
								cv = 3;
							if ( isDest )
								regmask |= 1 << cv;
							else
								regmask |= cv << ( ( k - 1 ) << 1 );
						}
						if ( !isDest )
							for ( ; k <= 4; k++ )
								regmask |= cv << ( ( k - 1 ) << 1 ); // repeat last								
					}
					else
					{
						regmask = isDest ? 0xf : 0xe4; // id swizzle or mask						
					}
					
					if ( isRelative )
					{
						var relname:Array = relreg[0].match( /[A-Za-z]{1,2}/ig );						
						var regFoundRel:Register = REGMAP[ relname[0]];						
						if ( regFoundRel == null )
						{ 
							_error = "error: bad index register"; 
							badreg = true; 
							break;
						}
						reltype = regFoundRel.emitCode;
						var selmatch:Array = relreg[0].match( /(\.[xyzw]{1,1})/ );						
						if ( selmatch.length==0 )
						{
							_error = "error: bad index register select"; 
							badreg = true; 
							break;						
						}
						relsel = selmatch[0].charCodeAt(1) - "x".charCodeAt(0);
						if ( relsel > 2 )
							relsel = 3; 
						var relofs:Array = relreg[0].match( /\+\d{1,3}/ig );
						if ( relofs.length > 0 ) 
							reloffset = relofs[0]; 						
						if ( reloffset < 0 || reloffset > 255 )
						{
							_error = "error: index offset "+reloffset+" out of bounds. [0..255]"; 
							badreg = true; 
							break;							
						}
						if ( verbose )
							trace( "RELATIVE: type="+reltype+"=="+relname[0]+" sel="+relsel+"=="+selmatch[0]+" idx="+regidx+" offset="+reloffset ); 
					}
					
					if ( verbose )
						trace( "  emit argcode="+regFound+"["+regidx+"]["+regmask+"]" );
					if ( isDest )
					{												
						agalcode.writeShort( regidx );
						agalcode.writeByte( regmask );
						agalcode.writeByte( regFound.emitCode );
						pad -= 32; 
					} else
					{
						if ( isSampler )
						{
							if ( verbose )
								trace( "  emit sampler" );
							var samplerbits:uint = 5; // type 5 
							var optsLength:uint = opts == null ? 0 : opts.length;
							var bias:Number = 0; 
							for ( k = 0; k<optsLength; k++ )
							{
								if ( verbose )
									trace( "    opt: "+opts[k] );
								var optfound:Sampler = SAMPLEMAP [opts[k]];
								if ( optfound == null )
								{
									// todo check that it's a number...
									//trace( "Warning, unknown sampler option: "+opts[k] );
									bias = Number(opts[k]); 
									if ( verbose )
										trace( "    bias: " + bias );																	
								}
								else
								{
									if ( optfound.flag != SAMPLER_SPECIAL_SHIFT )
										samplerbits &= ~( 0xf << optfound.flag );										
									samplerbits |= uint( optfound.mask ) << uint( optfound.flag );
								}
							}
							agalcode.writeShort( regidx );
							agalcode.writeByte(int(bias*8.0));
							agalcode.writeByte(0);							
							agalcode.writeUnsignedInt( samplerbits );
							
							if ( verbose )
								trace( "    bits: " + ( samplerbits - 5 ) );
							pad -= 64;
						}
						else
						{
							if ( j == 0 )
							{
								agalcode.writeUnsignedInt( 0 );
								pad -= 32;
							}
							agalcode.writeShort( regidx );
							agalcode.writeByte( reloffset );
							agalcode.writeByte( regmask );
							agalcode.writeByte( regFound.emitCode );
							agalcode.writeByte( reltype );
							agalcode.writeShort( isRelative ? ( relsel | ( 1 << 15 ) ) : 0 );
							
							pad -= 64;
						}
					}
				}
				
				// pad unused regs
				for ( j = 0; j < pad; j += 8 ) 
					agalcode.writeByte( 0 );
				
				if ( badreg )
					break;
			}
			
			if ( _error != "" )
			{
				_error += "\n  at line " + i + " " + lines[i];
				agalcode.length = 0;
				trace( _error );
			}
			
			// trace the bytecode bytes if debugging is enabled
			if ( debugEnabled )
			{
				var dbgLine:String = "generated bytecode:";
				var agalLength:uint = agalcode.length;
				for ( var index:uint = 0; index < agalLength; index++ )
				{
					if ( !( index % 16 ) )
						dbgLine += "\n";
					if ( !( index % 4 ) )
						dbgLine += " ";
					
					var byteStr:String = agalcode[ index ].toString( 16 );
					if ( byteStr.length < 2 )
						byteStr = "0" + byteStr;
					
					dbgLine += byteStr;
				}
				trace( dbgLine );
			}
			
			if ( verbose )
				trace( "AGALMiniAssembler.assemble time: " + ( ( getTimer() - start ) / 1000 ) + "s" );
			
			return agalcode;
		}
		
		static protected function init():void
		{
			initialized = true;
			
			// Fill the dictionaries with opcodes and registers
			OPMAP[ MOV ] = new OpCode( MOV, 2, 0x00, 0 );
			OPMAP[ ADD ] = new OpCode( ADD, 3, 0x01, 0 );
			OPMAP[ SUB ] = new OpCode( SUB, 3, 0x02, 0 );
			OPMAP[ MUL ] = new OpCode( MUL, 3, 0x03, 0 );
			OPMAP[ DIV ] = new OpCode( DIV, 3, 0x04, 0 );
			OPMAP[ RCP ] = new OpCode( RCP, 2, 0x05, 0 );					
			OPMAP[ MIN ] = new OpCode( MIN, 3, 0x06, 0 );
			OPMAP[ MAX ] = new OpCode( MAX, 3, 0x07, 0 );
			OPMAP[ FRC ] = new OpCode( FRC, 2, 0x08, 0 );			
			OPMAP[ SQT ] = new OpCode( SQT, 2, 0x09, 0 );
			OPMAP[ RSQ ] = new OpCode( RSQ, 2, 0x0a, 0 );
			OPMAP[ POW ] = new OpCode( POW, 3, 0x0b, 0 );
			OPMAP[ LOG ] = new OpCode( LOG, 2, 0x0c, 0 );
			OPMAP[ EXP ] = new OpCode( EXP, 2, 0x0d, 0 );
			OPMAP[ NRM ] = new OpCode( NRM, 2, 0x0e, 0 );
			OPMAP[ SIN ] = new OpCode( SIN, 2, 0x0f, 0 );
			OPMAP[ COS ] = new OpCode( COS, 2, 0x10, 0 );
			OPMAP[ CRS ] = new OpCode( CRS, 3, 0x11, 0 );
			OPMAP[ DP3 ] = new OpCode( DP3, 3, 0x12, 0 );
			OPMAP[ DP4 ] = new OpCode( DP4, 3, 0x13, 0 );					
			OPMAP[ ABS ] = new OpCode( ABS, 2, 0x14, 0 );
			OPMAP[ NEG ] = new OpCode( NEG, 2, 0x15, 0 );
			OPMAP[ SAT ] = new OpCode( SAT, 2, 0x16, 0 );
			OPMAP[ M33 ] = new OpCode( M33, 3, 0x17, OP_SPECIAL_MATRIX );
			OPMAP[ M44 ] = new OpCode( M44, 3, 0x18, OP_SPECIAL_MATRIX );
			OPMAP[ M34 ] = new OpCode( M34, 3, 0x19, OP_SPECIAL_MATRIX );			
			OPMAP[ IFZ ] = new OpCode( IFZ, 1, 0x1a, OP_NO_DEST | OP_INC_NEST | OP_SCALAR );
			OPMAP[ INZ ] = new OpCode( INZ, 1, 0x1b, OP_NO_DEST | OP_INC_NEST | OP_SCALAR );
			OPMAP[ IFE ] = new OpCode( IFE, 2, 0x1c, OP_NO_DEST | OP_INC_NEST | OP_SCALAR );
			OPMAP[ INE ] = new OpCode( INE, 2, 0x1d, OP_NO_DEST | OP_INC_NEST | OP_SCALAR );
			OPMAP[ IFG ] = new OpCode( IFG, 2, 0x1e, OP_NO_DEST | OP_INC_NEST | OP_SCALAR );
			OPMAP[ IFL ] = new OpCode( IFL, 2, 0x1f, OP_NO_DEST | OP_INC_NEST | OP_SCALAR );
			OPMAP[ IEG ] = new OpCode( IEG, 2, 0x20, OP_NO_DEST | OP_INC_NEST | OP_SCALAR );
			OPMAP[ IEL ] = new OpCode( IEL, 2, 0x21, OP_NO_DEST | OP_INC_NEST | OP_SCALAR );
			OPMAP[ ELS ] = new OpCode( ELS, 0, 0x22, OP_NO_DEST | OP_INC_NEST | OP_DEC_NEST );
			OPMAP[ EIF ] = new OpCode( EIF, 0, 0x23, OP_NO_DEST | OP_DEC_NEST );
			OPMAP[ REP ] = new OpCode( REP, 1, 0x24, OP_NO_DEST | OP_INC_NEST | OP_SCALAR );
			OPMAP[ ERP ] = new OpCode( ERP, 0, 0x25, OP_NO_DEST | OP_DEC_NEST );
			OPMAP[ BRK ] = new OpCode( BRK, 0, 0x26, OP_NO_DEST );
			OPMAP[ KIL ] = new OpCode( KIL, 1, 0x27, OP_NO_DEST | OP_FRAG_ONLY );
			OPMAP[ TEX ] = new OpCode( TEX, 3, 0x28, OP_FRAG_ONLY | OP_SPECIAL_TEX );
			OPMAP[ SGE ] = new OpCode( SGE, 3, 0x29, 0 );
			OPMAP[ SLT ] = new OpCode( SLT, 3, 0x2a, 0 );
			OPMAP[ SGN ] = new OpCode( SGN, 2, 0x2b, 0 );
			OPMAP[ SEQ ] = new OpCode( SEQ, 3, 0x2c, 0 );
			OPMAP[ SNE ] = new OpCode( SNE, 3, 0x2d, 0 );
			
			REGMAP[ VA ]	= new Register( VA,	"vertex attribute",		0x0,	7,		REG_VERT | REG_READ );
			REGMAP[ VC ]	= new Register( VC,	"vertex constant",		0x1,	127,	REG_VERT | REG_READ );
			REGMAP[ VT ]	= new Register( VT,	"vertex temporary",		0x2,	7,		REG_VERT | REG_WRITE | REG_READ );
			REGMAP[ VO ]	= new Register( VO,	"vertex output",		0x3,	0,		REG_VERT | REG_WRITE );
			REGMAP[ I ]		= new Register( I,	"varying",				0x4,	7,		REG_VERT | REG_FRAG | REG_READ | REG_WRITE );
			REGMAP[ FC ]	= new Register( FC,	"fragment constant",	0x1,	27,		REG_FRAG | REG_READ );
			REGMAP[ FT ]	= new Register( FT,	"fragment temporary",	0x2,	7,		REG_FRAG | REG_WRITE | REG_READ );
			REGMAP[ FS ]	= new Register( FS,	"texture sampler",		0x5,	7,		REG_FRAG | REG_READ );
			REGMAP[ FO ]	= new Register( FO,	"fragment output",		0x3,	0,		REG_FRAG | REG_WRITE );
			
			SAMPLEMAP[ RGBA ]		= new Sampler( RGBA,		SAMPLER_TYPE_SHIFT,			0 );
			SAMPLEMAP[ DXT1 ]		= new Sampler( DXT1,		SAMPLER_TYPE_SHIFT,			1 );
			SAMPLEMAP[ DXT5 ]		= new Sampler( DXT5,		SAMPLER_TYPE_SHIFT,			2 );
			SAMPLEMAP[ D2 ]			= new Sampler( D2,			SAMPLER_DIM_SHIFT,			0 );
			SAMPLEMAP[ D3 ]			= new Sampler( D3,			SAMPLER_DIM_SHIFT,			2 );
			SAMPLEMAP[ CUBE ]		= new Sampler( CUBE,		SAMPLER_DIM_SHIFT,			1 );
			SAMPLEMAP[ MIPNEAREST ]	= new Sampler( MIPNEAREST,	SAMPLER_MIPMAP_SHIFT,		1 );
			SAMPLEMAP[ MIPLINEAR ]	= new Sampler( MIPLINEAR,	SAMPLER_MIPMAP_SHIFT,		2 );
			SAMPLEMAP[ MIPNONE ]	= new Sampler( MIPNONE,		SAMPLER_MIPMAP_SHIFT,		0 );
			SAMPLEMAP[ NOMIP ]		= new Sampler( NOMIP,		SAMPLER_MIPMAP_SHIFT,		0 );
			SAMPLEMAP[ NEAREST ]	= new Sampler( NEAREST,		SAMPLER_FILTER_SHIFT,		0 );
			SAMPLEMAP[ LINEAR ]		= new Sampler( LINEAR,		SAMPLER_FILTER_SHIFT,		1 );
			SAMPLEMAP[ CENTROID ]	= new Sampler( CENTROID,	SAMPLER_SPECIAL_SHIFT,		1 << 0 );
			SAMPLEMAP[ SINGLE ]		= new Sampler( SINGLE,		SAMPLER_SPECIAL_SHIFT,		1 << 1 );
			SAMPLEMAP[ DEPTH ]		= new Sampler( DEPTH,		SAMPLER_SPECIAL_SHIFT,		1 << 2 );
			SAMPLEMAP[ REPEAT ]		= new Sampler( REPEAT,		SAMPLER_REPEAT_SHIFT,		1 );
			SAMPLEMAP[ WRAP ]		= new Sampler( WRAP,		SAMPLER_REPEAT_SHIFT,		1 );
			SAMPLEMAP[ CLAMP ]		= new Sampler( CLAMP,		SAMPLER_REPEAT_SHIFT,		0 );
		}
		
		// ======================================================================
		//	Constants
		// ----------------------------------------------------------------------
		protected static const OPMAP:Dictionary					= new Dictionary();
		protected static const REGMAP:Dictionary					= new Dictionary();
		protected static const SAMPLEMAP:Dictionary				= new Dictionary();
		
		protected static const MAX_NESTING:int					= 4;
		protected static const MAX_OPCODES:int					= 256;
		
		protected static const FRAGMENT:String					= "fragment";
		protected static const VERTEX:String						= "vertex";
		
		// masks and shifts
		protected static const SAMPLER_TYPE_SHIFT:uint			= 8;
		protected static const SAMPLER_DIM_SHIFT:uint				= 12;
		protected static const SAMPLER_SPECIAL_SHIFT:uint			= 16;
		protected static const SAMPLER_REPEAT_SHIFT:uint			= 20;
		protected static const SAMPLER_MIPMAP_SHIFT:uint			= 24;
		protected static const SAMPLER_FILTER_SHIFT:uint			= 28;
		
		// regmap flags
		protected static const REG_WRITE:uint						= 0x1;
		protected static const REG_READ:uint						= 0x2;
		protected static const REG_FRAG:uint						= 0x20;
		protected static const REG_VERT:uint						= 0x40;
		
		// opmap flags
		protected static const OP_SCALAR:uint						= 0x1;
		protected static const OP_INC_NEST:uint					= 0x2;
		protected static const OP_DEC_NEST:uint					= 0x4;
		protected static const OP_SPECIAL_TEX:uint				= 0x8;
		protected static const OP_SPECIAL_MATRIX:uint				= 0x10;
		protected static const OP_FRAG_ONLY:uint					= 0x20;
		//protected static const OP_VERT_ONLY:uint				= 0x40;
		protected static const OP_NO_DEST:uint					= 0x80;
		
		// opcodes
		protected static const MOV:String							= "mov";
		protected static const ADD:String							= "add";
		protected static const SUB:String							= "sub";
		protected static const MUL:String							= "mul";
		protected static const DIV:String							= "div";
		protected static const RCP:String							= "rcp";
		protected static const MIN:String							= "min";
		protected static const MAX:String							= "max";
		protected static const FRC:String							= "frc";
		protected static const SQT:String							= "sqt";
		protected static const RSQ:String							= "rsq";
		protected static const POW:String							= "pow";
		protected static const LOG:String							= "log";
		protected static const EXP:String							= "exp";
		protected static const NRM:String							= "nrm";
		protected static const SIN:String							= "sin";
		protected static const COS:String							= "cos";
		protected static const CRS:String							= "crs";
		protected static const DP3:String							= "dp3";
		protected static const DP4:String							= "dp4";
		protected static const ABS:String							= "abs";
		protected static const NEG:String							= "neg";
		protected static const SAT:String							= "sat";
		protected static const M33:String							= "m33";
		protected static const M44:String							= "m44";
		protected static const M34:String							= "m34";
		protected static const IFZ:String							= "ifz";
		protected static const INZ:String							= "inz";
		protected static const IFE:String							= "ife";
		protected static const INE:String							= "ine";
		protected static const IFG:String							= "ifg";
		protected static const IFL:String							= "ifl";
		protected static const IEG:String							= "ieg";
		protected static const IEL:String							= "iel";
		protected static const ELS:String							= "els";
		protected static const EIF:String							= "eif";
		protected static const REP:String							= "rep";
		protected static const ERP:String							= "erp";
		protected static const BRK:String							= "brk";
		protected static const KIL:String							= "kil";
		protected static const TEX:String							= "tex";
		protected static const SGE:String							= "sge";
		protected static const SLT:String							= "slt";
		protected static const SGN:String							= "sgn";
		protected static const SEQ:String							= "seq";
		protected static const SNE:String							= "sne";
		
		// registers
		protected static const VA:String							= "va";
		protected static const VC:String							= "vc";
		protected static const VT:String							= "vt";
		protected static const VO:String							= USE_NEW_SYNTAX ? "vo" : "op";
		protected static const I:String							= USE_NEW_SYNTAX ? "i" : "v";
		protected static const FC:String							= "fc";
		protected static const FT:String							= "ft";
		protected static const FS:String							= "fs";
		protected static const FO:String							= USE_NEW_SYNTAX ? "fo" : "oc";
		
		// samplers
		protected static const D2:String							= "2d";
		protected static const D3:String							= "3d";
		protected static const CUBE:String						= "cube";
		protected static const MIPNEAREST:String					= "mipnearest";
		protected static const MIPLINEAR:String					= "miplinear";
		protected static const MIPNONE:String						= "mipnone";
		protected static const NOMIP:String						= "nomip";
		protected static const NEAREST:String						= "nearest";
		protected static const LINEAR:String						= "linear";
		protected static const CENTROID:String					= "centroid";
		protected static const SINGLE:String						= "single";
		protected static const DEPTH:String						= "depth";
		protected static const REPEAT:String						= "repeat";
		protected static const WRAP:String						= "wrap";
		protected static const CLAMP:String						= "clamp";
		protected static const RGBA:String						= "rgba";
		protected static const DXT1:String						= "dxt1";
		protected static const DXT5:String						= "dxt5";
	}
}

// ================================================================================
//	Helper Classes
// --------------------------------------------------------------------------------
{
	// ===========================================================================
	//	Class
	// ---------------------------------------------------------------------------
	class OpCode
	{		
		// ======================================================================
		//	Properties
		// ----------------------------------------------------------------------
		protected var _emitCode:uint;
		protected var _flags:uint;
		protected var _name:String;
		protected var _numRegister:uint;
		
		// ======================================================================
		//	Getters
		// ----------------------------------------------------------------------
		public function get emitCode():uint		{ return _emitCode; }
		public function get flags():uint		{ return _flags; }
		public function get name():String		{ return _name; }
		public function get numRegister():uint	{ return _numRegister; }
		
		// ======================================================================
		//	Constructor
		// ----------------------------------------------------------------------
		public function OpCode( name:String, numRegister:uint, emitCode:uint, flags:uint)
		{
			_name = name;
			_numRegister = numRegister;
			_emitCode = emitCode;
			_flags = flags;
		}		
		
		// ======================================================================
		//	Methods
		// ----------------------------------------------------------------------
		public function toString():String
		{
			return "[OpCode name=\""+_name+"\", numRegister="+_numRegister+", emitCode="+_emitCode+", flags="+_flags+"]";
		}
	}
	
	// ===========================================================================
	//	Class
	// ---------------------------------------------------------------------------
	class Register
	{
		// ======================================================================
		//	Properties
		// ----------------------------------------------------------------------
		protected var _emitCode:uint;
		protected var _name:String;
		protected var _longName:String;
		protected var _flags:uint;
		protected var _range:uint;
		
		// ======================================================================
		//	Getters
		// ----------------------------------------------------------------------
		public function get emitCode():uint		{ return _emitCode; }
		public function get longName():String	{ return _longName; }
		public function get name():String		{ return _name; }
		public function get flags():uint		{ return _flags; }
		public function get range():uint		{ return _range; }
		
		// ======================================================================
		//	Constructor
		// ----------------------------------------------------------------------
		public function Register( name:String, longName:String, emitCode:uint, range:uint, flags:uint)
		{
			_name = name;
			_longName = longName;
			_emitCode = emitCode;
			_range = range;
			_flags = flags;
		}
		
		// ======================================================================
		//	Methods
		// ----------------------------------------------------------------------
		public function toString():String
		{
			return "[Register name=\""+_name+"\", longName=\""+_longName+"\", emitCode="+_emitCode+", range="+_range+", flags="+ _flags+"]";
		}
	}
	
	// ===========================================================================
	//	Class
	// ---------------------------------------------------------------------------
	class Sampler
	{
		// ======================================================================
		//	Properties
		// ----------------------------------------------------------------------
		protected var _flag:uint;
		protected var _mask:uint;
		protected var _name:String;
		
		// ======================================================================
		//	Getters
		// ----------------------------------------------------------------------
		public function get flag():uint		{ return _flag; }
		public function get mask():uint		{ return _mask; }
		public function get name():String	{ return _name; }
		
		// ======================================================================
		//	Constructor
		// ----------------------------------------------------------------------
		public function Sampler( name:String, flag:uint, mask:uint )
		{
			_name = name;
			_flag = flag;
			_mask = mask;
		}
		
		// ======================================================================
		//	Methods
		// ----------------------------------------------------------------------
		public function toString():String
		{
			return "[Sampler name=\""+_name+"\", flag=\""+_flag+"\", mask="+mask+"]";
		}
	}
	}