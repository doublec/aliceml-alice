(* -*- sml -*- *)
(*
 * Authors:
 *   Leif Kornstaedt <kornstae@ps.uni-sb.de>
 *   Andreas Rossberg <rossberg@ps.uni-sb.de>
 *
 * Copyright:
 *   Leif Kornstaedt and Andreas Rossberg, 1999-2003
 *
 * Last change:
 *   $Date$ by $Author$
 *   $Revision$
 *)

(*
 *  Items marked with (**) are extensions to the Standard Basis.
 *)

changequote([[,]])

import structure __pervasive          from "Pervasive"
import __primitive
       type unit and bool and exn
       datatype alt                   from "ToplevelTypes"
import __primitive infix 4 = val op = from "ToplevelValues"
import __primitive structure Hole     from "Hole"
import __primitive structure Time     from "Time"
import __primitive signature FUTURE   from "FUTURE-sig"

structure Future :> FUTURE =				(**)
struct
    datatype  status = FUTURE | FAILED | DETERMINED

    __primitive exception Cyclic			= "Future.Cyclic"
    __primitive val concur :	(unit -> 'a) -> 'a	= "Future.concur"
    __primitive val byneed :	(unit -> 'a) -> 'a	= "Future.byneed"
    __primitive val alarm :	Time.time -> unit	= "Future.alarm'"

    __primitive val await :	'a -> 'a		= "Future.await"

ifdef([[FUTURE_AWAIT_EITHER_IS_PRIMITIVE]],[[
(* The implementation of awaitEither has a race condition under Mozart,
 * hence we make it primitive for now ... *)
    __primitive val awaitEither' : 'a * 'b -> bool = "Future.awaitEither'"
    fun awaitEither (a, b) =
	if awaitEither' (a, b) then SND b else FST a
]],[[
    local
	type thread
	__primitive val currentThread: unit -> thread = "Thread.current"
	__primitive val raiseIn: thread * exn -> unit = "Thread.raiseIn"
	__primitive exception Terminate  = "Thread.Terminate"
	__primitive exception Terminated = "Thread.Terminated"
    in
	fun awaitEither (a, b) =
	    let
		exception AwaitEitherTerminate
		val c  = Hole.hole ()
		val t1 = Hole.hole ()
		val t2 = Hole.hole ()
	    in
		spawn (Hole.fill (t1, currentThread ());
		       (await a; ()) handle _ => ();
		       Hole.fill (c, FST a) handle Hole.Hole => ();
		       raiseIn (t2, AwaitEitherTerminate));
		spawn (Hole.fill (t2, currentThread ());
		       (await b; ()) handle _ => ();
		       Hole.fill (c, SND b) handle Hole.Hole => ();
		       raiseIn (t1, AwaitEitherTerminate));
		await (Hole.future c)
	    end
    end
]])

    __primitive val status : 'a -> status	= "Future.status"
    __primitive val isLazy : 'a -> bool		= "Future.isByneed"

    fun isFuture x	= status x = FUTURE
    fun isFailed x	= status x = FAILED
    fun isDetermined x	= status x = DETERMINED
end