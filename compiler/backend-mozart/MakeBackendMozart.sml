(*
 * Author:
 *   Leif Kornstaedt <kornstae@ps.uni-sb.de>
 *
 * Copyright:
 *   Leif Kornstaedt, 2000-2001
 *
 * Last change:
 *   $Date$ by $Author$
 *   $Revision$
 *)

structure MozartEngine =
    MakeEngine(fun cmd () =
		   ("/bin/sh",
		    [(*--**"/opt/mozart-1.1.1/bin/ozd", "-p",*)
		     case OS.Process.getEnv "STOC_MOZART" of
			 SOME s => s
		       | NONE => "stoc-mozart.exe"])
	       structure Code = PickleFlatGrammar)

functor MakeMozartTarget(structure Switches: SWITCHES
			 structure Sig: SIGNATURE
			     where type t = FlatGrammar.sign): TARGET =
    struct
	structure C = MozartEngine.C
	structure Sig = Sig

	type t = Source.desc * string option ref * FlatGrammar.t

	fun sign (_, _, (_, _, _, exportSign)) = exportSign

	fun save context targetFilename code =
	    MozartEngine.save context
	    (MozartEngine.link context code, targetFilename)

	fun apply context (code as (_, _, (_, _, exportDesc, _))) =
	    MozartEngine.apply context
	    (MozartEngine.link context code, exportDesc)
    end

functor MakeBackendMozart(structure Switches: SWITCHES
			  structure MozartTarget: TARGET
			      where type t = Source.desc * string option ref *
					     FlatGrammar.t): PHASE =
    MakeTracingPhase(structure Phase =
			 struct
			     structure C = EmptyContext
			     structure I = FlatGrammar
			     structure O = MozartTarget

			     fun translate () (desc, component) =
				 (desc, ref NONE, component)
			 end
		     structure Switches = Switches
		     val name = "Assembling")
