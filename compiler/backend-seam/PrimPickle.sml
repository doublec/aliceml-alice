(*
 * Author:
 *   Leif Kornstaedt <kornstae@ps.uni-sb.de>
 *
 * Copyright:
 *   Leif Kornstaedt, 2000
 *
 * Last change:
 *   $Date$ by $Author$
 *   $Revision$
 *)

structure PrimPickle :> PRIM_PICKLE =
    struct
	open LargeInt

	type id = int

	structure StringMap = MakeHashImpMap(StringHashKey)

	type outstream = BinIO.outstream * id ref * id StringMap.t

	fun inc (_, r as ref id, _) = (r := id + 1; id)

	fun lookupString ((_, _, stringMap), s) =
	    StringMap.lookup (stringMap, s)

	fun insertString ((_, _, stringMap), s, id) =
	    StringMap.insertDisjoint (stringMap, s, id)

	type label = int
	type size = Int.int

	val tPOSINT    = 0w0: Word8.word
	val tNEGINT    = 0w1: Word8.word
	val tCHUNK     = 0w2: Word8.word
	val tBLOCK     = 0w3: Word8.word
	val tCLOSURE   = 0w4: Word8.word
	val tREF       = 0w5: Word8.word
	val tTRANSFORM = 0w6: Word8.word

	fun outputByte ((outstream, _, _), w) = BinIO.output1 (outstream, w)

	fun outputUInt (q, i) =
	    if i >= 0x80 then
		(outputByte (q, Word8.fromLargeInt (i mod 0x80 + 0x80));
		 outputUInt (q, i div 0x80))
	    else if i >= 0 then outputByte (q, Word8.fromLargeInt i)
	    else raise Crash.Crash "PrimPickle.outputUInt"

	fun openOut name: outstream =
	    (BinIO.openOut name, ref 0, StringMap.new ())

	fun outputInt (q, i) =
	    if i >= 0 then (outputByte (q, tPOSINT); outputUInt (q, i))
	    else (outputByte (q, tNEGINT); outputUInt (q, ~(i + 1)))

	fun outputChunk (q, bytes) =
	    (outputByte (q, tCHUNK);
	     outputUInt (q, fromInt (Vector.length bytes));
	     Vector.app (fn b => outputByte (q, b)) bytes; inc q)

	fun outputBlock (q, label, size) =
	    (outputByte (q, tBLOCK); outputUInt (q, label);
	     outputUInt (q, fromInt size); inc q)

	fun outputClosure (q, size) =
	    (outputByte (q, tCLOSURE); outputUInt (q, fromInt size); inc q)

	fun outputReference (q, id) =
	    (outputByte (q, tREF); outputUInt (q, id))

	fun outputString (q, s) =
	    case lookupString (q, s) of
		SOME id => (outputReference (q, id); id)
	      | NONE =>
		    let
			val id = inc q
		    in
			insertString (q, s, id);
			outputByte (q, tCHUNK);
			outputUInt (q, fromInt (String.size s));
			CharVector.app
			(fn c => outputByte (q, Word8.fromInt (Char.ord c))) s;
			id
		    end

	fun outputTransform (q, name) =
	    let
		val id = inc q
	    in
		outputByte (q, tTRANSFORM); outputString (q, name); id
	    end

	fun closeOut (outstream, _, _) = BinIO.closeOut outstream
    end
