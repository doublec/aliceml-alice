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

signature OS_COMPONENT =
    sig
	structure OS:
	    sig
		structure Process:
		    sig
			val getEnv: string -> string option
		    end
	    end
    end
