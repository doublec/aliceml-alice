(*
 * Author:
 *   Leif Kornstaedt <kornstae@ps.uni-sb.de>
 *
 * Copyright:
 *   Leif Kornstaedt, 2001-2003
 *
 * Last change:
 *   $Date$ by $Author$
 *   $Revision$
 *)

(* Dummy replacement for bootstrapping *)

structure Component :> COMPONENT =
    struct
	type component = unit
	type t = component

	exception Sited
	exception Corrupt
	exception NotFound

	exception Mismatch of {component : Url.t,
			       request : Url.t option,
			       cause : Inf.mismatch}
	exception Eval of exn
	exception Failure of Url.t * exn

	fun inf _ = NONE
	fun load url =
	    raise IO.Io {name = Url.toStringRaw url,
			 function = "load", cause = Corrupt}
	fun save (name, _) =
	    raise IO.Io {name = name, function = "save", cause = Sited}

	structure Manager: COMPONENT_MANAGER =
	    struct
		exception Conflict

		type component = component

		fun eval (url, _) = raise Failure (url, Eval NotFound)
		fun link url =
		    raise Failure (url, IO.Io {name = Url.toStringRaw url,
					       function = "link",
					       cause = Corrupt})
		fun lookup _ = NONE
		fun enter (_, _) = raise Conflict
	    end
    end

structure ComponentManager = Component.Manager
