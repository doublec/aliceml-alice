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

structure DeadCodeEliminationPhase :> DEAD_CODE_ELIMINATION_PHASE =
    struct
	structure C = EmptyContext
	structure I = FlatGrammar
	structure O = FlatGrammar

	open I

	fun killSet body =
	    case !(#liveness (infoStm (List.hd body))) of
		Kill set => set
	      | _ => raise Crash.Crash "DeadCodeEliminationPhase.killSet"

	fun elim (info: stm_info, body) =
	    (*--** do not merge kills into a SharedStm *)
	    (case !(#liveness info) of
		 Kill fromSet =>
		     let
			 val toSet = killSet body
		     in
			 StampSet.app (fn stamp =>
				       StampSet.insert (toSet, stamp)) fromSet
		     end
	       | _ => ();   (*--** when does this happen? *)
	     body)

	fun killIdDef (idDef as IdDef (Id (_, stamp, _)), set) =
	    if StampSet.member (set, stamp) then
		(StampSet.delete (set, stamp); Wildcard)
	    else idDef
	  | killIdDef (Wildcard, _) = Wildcard

	fun killArgs (OneArg idDef, set) = OneArg (killIdDef (idDef, set))
	  | killArgs (TupArgs idDefs, set) =
	    TupArgs (Vector.map (fn idDef => killIdDef (idDef, set)) idDefs)
	  | killArgs (ProdArgs labelIdDefVec, set) =
	    ProdArgs (Vector.map (fn (label, idDef) =>
				  (label, killIdDef (idDef, set)))
		      labelIdDefVec)

	fun killConArgs (SOME args, set) = SOME (killArgs (args, set))
	  | killConArgs (NONE, _) = NONE

	fun deadExp (LitExp (_, _)) = NONE
	  | deadExp (PrimExp (_, _)) = NONE
	  | deadExp (NewExp _) = NONE
	  | deadExp (VarExp (_, _)) = NONE
	  | deadExp (TagExp (_, _, _)) = NONE
	  | deadExp (TupExp (_, _)) = NONE
	  | deadExp (ProdExp (_, _)) = NONE
	  | deadExp (VecExp (_, _)) = NONE
	  | deadExp (FunExp (_, _, _, _, _)) = NONE
	  | deadExp (RefAppExp (_, _)) = NONE
	  | deadExp exp = SOME exp

	fun liveBody (ValDec (info, idDef, exp)::rest, shared) =
	    let
		val rest = liveBody (rest, shared)
	    in
		case killIdDef (idDef, killSet rest) of
		    idDef as IdDef _ =>
			ValDec (info, idDef, liveExp (exp, shared))::rest
		  | Wildcard =>
			(case deadExp exp of
			     SOME exp =>
				 ValDec (info, Wildcard, exp)::rest
			   | NONE => elim (info, rest))
	    end
	  | liveBody (RefAppDec (info, idDef, id)::rest, shared) =
	    let
		val rest = liveBody (rest, shared)
	    in
		RefAppDec (info, killIdDef (idDef, killSet rest), id)::rest
	    end
	  | liveBody (TupDec (info, idDefs, id)::rest, shared) =
	    let
		val rest = liveBody (rest, shared)
		val set = killSet rest
		val idDefs =
		    Vector.map (fn idDef => killIdDef (idDef, set)) idDefs
	    in
		TupDec (info, idDefs, id)::rest
	    end
	  | liveBody (ProdDec (info, labelIdDefVec, id)::rest, shared) =
	    let
		val rest = liveBody (rest, shared)
		val set = killSet rest
		val labelIdDefVec =
		    Vector.map (fn (label, idDef) =>
				(label, killIdDef (idDef, set))) labelIdDefVec
	    in
		ProdDec (info, labelIdDefVec, id)::rest
	    end
	  | liveBody (body as [RaiseStm (_, _)], _) = body
	  | liveBody (body as [ReraiseStm (_, _)], _) = body
	  | liveBody ([TryStm (info, tryBody, idDef1, idDef2, handleBody)],
		      shared) =
	    (case liveBody (tryBody, shared) of
		 [EndTryStm (_, body)] => body
	       | tryBody =>
		     let
			 val handleBody = liveBody (handleBody, shared)
			 val idDef1 = killIdDef (idDef1, killSet handleBody)
			 val idDef2 = killIdDef (idDef2, killSet handleBody)
		     in
			 [TryStm (info, tryBody, idDef1, idDef2, handleBody)]
		     end)
	  | liveBody ([EndTryStm (info, body)], shared) =
	    [EndTryStm (info, liveBody (body, shared))]
	  | liveBody ([EndHandleStm (info, body)], shared) =
	    [EndHandleStm (info, liveBody (body, shared))]
	  | liveBody ([TestStm (info, id, tests, body)], shared) =
	    let
		val tests =
		    case tests of
			LitTests tests =>
			    LitTests (Vector.map
				      (fn (lit, body) =>
				       (lit, liveBody (body, shared))) tests)
		      | TagTests tests =>
			    TagTests (Vector.map
				      (fn (label, tag, conArgs, body) =>
				       let
					   val body = liveBody (body, shared)
					   val set = killSet body
					   val conArgs =
					       killConArgs (conArgs, set)
				       in
					   (label, tag, conArgs, body)
				       end) tests)
		      | ConTests tests =>
			    ConTests (Vector.map
				      (fn (con, conArgs, body) =>
				       let
					   val body = liveBody (body, shared)
					   val set = killSet body
					   val conArgs =
					       killConArgs (conArgs, set)
				       in
					   (con, conArgs, body)
				       end) tests)
		      | VecTests tests =>
			    VecTests (Vector.map
				      (fn (idDefs, body) =>
				       let
					   val body = liveBody (body, shared)
					   val set = killSet body
				       in
					   (Vector.map (fn idDef =>
							killIdDef (idDef, set))
					    idDefs, body)
				       end) tests)
	    in
		[TestStm (info, id, tests, liveBody (body, shared))]
	    end
	  | liveBody ([SharedStm (info, body, stamp)], shared) =
	    (*--** remove trivial shared statements? *)
	    (case StampMap.lookup (shared, stamp) of
		 SOME body => body
	       | NONE =>
		     let
			 val body' =
			     [SharedStm (info, liveBody (body, shared), stamp)]
		     in
			 StampMap.insert (shared, stamp, body'); body'
		     end)
	  | liveBody ([ReturnStm (info, exp)], shared) =
	    [ReturnStm (info, liveExp (exp, shared))]
	  | liveBody ([IndirectStm (info, ref bodyOpt)], shared) =
	    elim (info, liveBody (valOf bodyOpt, shared))
	  | liveBody ([ExportStm (info, exp)], shared) =
	    [ExportStm (info, liveExp (exp, shared))]
	  | liveBody (((RaiseStm (_, _) | ReraiseStm (_, _) |
			TryStm (_, _, _, _, _) | EndTryStm (_, _) |
			EndHandleStm (_, _) | TestStm (_, _, _, _) |
			SharedStm (_, _, _) | ReturnStm (_, _) |
			IndirectStm (_, _) | ExportStm (_, _))::_::_ | nil),
		      _) =
	    raise Crash.Crash "DeadCodeEliminationPhase.liveBody 2"
	and liveExp (FunExp (info, stamp, funFlags, args, body), shared) =
	    let
		val body = liveBody (body, shared)
	    in
		FunExp (info, stamp, funFlags,
			killArgs (args, killSet body), body)
	    end
	  | liveExp (exp, _) = exp

	fun translate () (_, component as (imports, (body, sign))) =
	    (imports, (liveBody (body, StampMap.new ()), sign))
    end
