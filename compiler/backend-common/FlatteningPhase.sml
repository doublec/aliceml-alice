(*
 * Author:
 *   Leif Kornstaedt <kornstae@ps.uni-sb.de>
 *
 * Copyright:
 *   Leif Kornstaedt, 1999-2000
 *
 * Last change:
 *   $Date$ by $Author$
 *   $Revision$
 *)

structure FlatteningPhase :> FLATTENING_PHASE =
    struct
	structure C = EmptyContext
	structure I = IntermediateGrammar
	structure O = FlatGrammar

	open I
	open IntermediateAux
	open SimplifyMatch

	local
	    fun lookup' (pos, (pos', id)::mappingRest) =
		if pos = pos' then SOME id
		else lookup' (pos, mappingRest)
	      | lookup' (pos, nil) = NONE
	in
	    fun lookup (pos, mapping) =
		case lookup' (pos, mapping) of
		    SOME id => id
		  | NONE => raise Crash.Crash "FlatteningPhase.lookup"

	    fun adjoin (pos, mapping) =
		case lookup' (pos, mapping) of
		    SOME id => (O.IdDef id, mapping)
		  | NONE =>
			let
			    val id = O.freshId {region = Source.nowhere}
			in
			    (O.IdDef id, (pos, id)::mapping)
			end
	end

	fun mappingsToSubst (mapping0, mapping) =
	    List.map (fn (pos, Id (_, stamp1, _)) =>
		      case lookup (pos, mapping) of
			  O.Id (_, stamp2, _) => (stamp1, stamp2)) mapping0

	fun stm_info region = {region = region, liveness = ref O.Unknown}

	fun share nil = nil
	  | share (stms as [O.SharedStm (_, _, _)]) = stms
	  | share (stms as stm::_) =
	    [O.SharedStm (stm_info (#region (O.infoStm stm)), stms,
			  Stamp.new ())]

	datatype continuation =
	    Decs of dec list * continuation
	  | Goto of O.body
	  | Share of O.body option ref * continuation

	(* Matching conArity up with args *)

	fun testArity (args as O.OneArg _, Arity.Unary, app, body) =
	    app (args, body)
	  | testArity (O.OneArg idDef, Arity.Tuple n, app, body) =
	    let
		val ids =
		    Vector.tabulate
		    (n, fn _ => O.freshId {region = Source.nowhere})
		val stm =
		    O.ValDec (stm_info Source.nowhere, idDef,
			      O.TupExp ({region = Source.nowhere}, ids))
	    in
		app (O.TupArgs (Vector.map O.IdDef ids), stm::body)
	    end
	  | testArity (O.OneArg idDef, Arity.Product labels, app, body) =
	    let
		val labelIdVec =
		    Vector.map (fn label =>
				(label, O.freshId {region = Source.nowhere}))
		    labels
		val stm =
		    O.ValDec (stm_info Source.nowhere, idDef,
			      O.ProdExp ({region = Source.nowhere},
					 labelIdVec))
		val labelIdDefVec =
		    Vector.map (fn (label, id) => (label, O.IdDef id))
		    labelIdVec
	    in
		app (O.ProdArgs labelIdDefVec, stm::body)
	    end
	  | testArity (args as O.TupArgs _, Arity.Tuple _, app, body) =
	    app (args, body)
	  | testArity (args as O.ProdArgs _, Arity.Product _, app, body) =
	    app (args, body)
	  | testArity (_, _, _, _) =
	    raise Crash.Crash "FlatteningPhase.testArity"

	fun tagAppTest (label, n, args, SOME arity, body) =
	    testArity (args, arity,
		       fn (args, body) =>
		       O.TagTests #[(label, n, SOME args, body)], body)
	  | tagAppTest (_, _, _, NONE, _) =
	    raise Crash.Crash "FlatteningPhase.tagAppTest"

	fun conAppTest (con, args, SOME arity, body) =
	    testArity (args, arity,
		       fn (args, body) =>
		       O.ConTests #[(con, SOME args, body)], body)
	  | conAppTest (_, _, NONE, _) =
	    raise Crash.Crash "FlatteningPhase.conAppTest"

	fun expArity (args as O.OneArg _, Arity.Unary, info, app) =
	    (nil, app args)
	  | expArity (O.OneArg id, Arity.Tuple n, info: id_info, app) =
	    let
		val ids =
		    Vector.tabulate
		    (n, fn _ => O.freshId {region = Source.nowhere})
		val idDefs = Vector.map O.IdDef ids
	    in
		([O.TupDec (stm_info (#region info), idDefs, id)],
		 app (O.TupArgs ids))
	    end
	  | expArity (O.OneArg id, Arity.Product labels, info, app) =
	    let
		val labelIdVec =
		    Vector.map (fn label =>
			      (label, O.freshId {region = Source.nowhere}))
		    labels
		val labelIdDefVec =
		    Vector.map (fn (label, id) => (label, O.IdDef id))
		    labelIdVec
	    in
		([O.ProdDec (stm_info (#region info), labelIdDefVec, id)],
		 app (O.ProdArgs labelIdVec))
	    end
	  | expArity (args as O.TupArgs _, Arity.Tuple _, _, app) =
	    (nil, app args)
	  | expArity (args as O.ProdArgs _, Arity.Product _, _, app) =
	    (nil, app args)
	  | expArity (_, _, _, _) =
	    raise Crash.Crash "FlatteningPhase.expArity"

	fun tagAppExp (info, label, n, args, SOME arity) =
	    expArity (args, arity, info,
		      fn args => O.TagAppExp (id_info info, label, n, args))
	  | tagAppExp (info, _, _, _, NONE) =
	    raise Crash.Crash "FlatteningPhase.tagAppExp"

	fun conAppExp (info, id, args, SOME arity) =
	    expArity (args, arity, info,
		      fn args => O.ConAppExp (id_info info, id, args))
	  | conAppExp (info, _, _, NONE) =
	    raise Crash.Crash "FlatteningPhase.conAppExp"

	(* Translation *)

	fun translateId (Id (info, stamp, name)) =
	    O.Id (id_info info, stamp, name)

	fun translateLongid (ShortId (info, id)) =
	    (nil, translateId id, #typ info)
	  | translateLongid (LongId ({region, typ}, longid, Lab (_, label))) =
	    let
		val (stms, id, innerTyp) = translateLongid longid
		val info = {region = region}
		val id' = O.Id (info, Stamp.new (), Name.InId)
		val (prod, n) = labelToIndex (innerTyp, label)
		val stm =
		    O.ValDec (stm_info region, O.IdDef id',
			      O.SelAppExp (info, prod, label, n, id))
	    in
		(stms @ [stm], id', typ)
	    end

	fun decsToIdDefExpList (O.ValDec (_, idDef, exp')::rest, region) =
	    (idDef, exp')::decsToIdDefExpList (rest, region)
	  | decsToIdDefExpList (O.IndirectStm (_, ref bodyOpt)::rest, region) =
	    decsToIdDefExpList (valOf bodyOpt, region) @
	    decsToIdDefExpList (rest, region)
	  | decsToIdDefExpList (_::_, region) =
	    Error.error (region, "not admissible")
	  | decsToIdDefExpList (nil, _) = nil

	fun translateIf (info: exp_info, id, thenStms, elseStms, errStms) =
	    [O.TestStm (stm_info (#region info), id,
			O.TagTests #[(PervasiveType.lab_true, 1, NONE,
				      thenStms),
				     (PervasiveType.lab_false, 0, NONE,
				      elseStms)], errStms)]

	fun raisePrim (region, name) =
	    let
		val info = {region = region}
		val id = O.freshId info
	    in
		[O.ValDec (stm_info region, O.IdDef id,
			   O.PrimExp (info, name)),
		 O.RaiseStm (stm_info region, id)]
	    end

	fun translateCont (Decs (dec::decr, cont)) =
	    translateDec (dec, Decs (decr, cont))
	  | translateCont (Decs (nil, cont)) = translateCont cont
	  | translateCont (Goto stms) = stms
	  | translateCont (Share (r as ref NONE, cont)) =
	    let
		val stms = share (translateCont cont)
	    in
		r := SOME stms; stms
	    end
	  | translateCont (Share (ref (SOME stms), _)) = stms
	and translateDec (ValDec (info, VarPat (_, id), exp), cont) =
	    let
		fun declare exp' =
		    O.ValDec (stm_info (#region info),
			      O.IdDef (translateId id), exp')
	    in
		translateExp (exp, declare, cont)
	    end
	  | translateDec (ValDec (info, pat, exp), cont) =
	    let
		val matches = #[(#region info, pat, translateCont cont)]
		val info = {region = #region info, typ = PervasiveType.typ_exn}
	    in
		simplifyCase (#region info, exp, matches,
			      PrimExp (info, "General.Bind"), false)
	    end
	  | translateDec (RecDec (info, decs), cont) =
	    let
		val (constraints, idExpList, aliases) =
		    SimplifyRec.derec (Vector.toList decs)
		val aliasDecs =
		    List.map (fn (fromId, toId, info) =>
			      O.ValDec (stm_info (#region info),
					O.IdDef (translateId fromId),
					O.VarExp (id_info info,
						  translateId toId))) aliases
		val subst =
		    List.map (fn (Id (_, stamp1, _), Id (_, stamp2, _), _) =>
			      (stamp1, stamp2)) aliases
		val decs' =
		    List.foldr
		    (fn ((id, exp), decs) =>
		     translateExp (substExp (exp, subst),
				   fn exp' =>
				   O.ValDec (stm_info (#region (infoExp exp)),
					     O.IdDef (translateId id), exp'),
				   Goto decs)) nil idExpList
		val idDefExpList' = decsToIdDefExpList (decs', #region info)
		val rest =
		    O.RecDec (stm_info (#region info),
			      Vector.fromList idDefExpList')::
		    aliasDecs @ translateCont cont
		val errStms = share (raisePrim (#region info, "General.Bind"))
	    in
		List.foldr
		(fn ((longid1, longid2), rest) =>
		 let
		     val (stms1, id1, _) = translateLongid longid1
		     val (stms2, id2, _) = translateLongid longid2
		 in
		     (* the following ConTest has `wrong' arity *)
		     stms1 @ stms2 @
		     [O.TestStm (stm_info (#region info), id1,
				 O.ConTests #[(O.Con id2, NONE, rest)],
				 errStms)]
		 end) rest constraints
	    end
	and unfoldTerm (VarExp (_, longid), cont) =
	    let
		val (stms, id, _) = translateLongid longid
	    in
		(stms @ translateCont cont, id)
	    end
	  | unfoldTerm (exp, cont) =
	    let
		val info = infoExp exp
		val id' = O.freshId (id_info info)
		fun declare exp' =
		    O.ValDec (stm_info (#region info), O.IdDef id', exp')
		val stms = translateExp (exp, declare, cont)
	    in
		(stms, id')
	    end
	and unfoldArgs (TupExp (_, exps), rest, true) =
	    let
		val (stms, ids) =
		    Vector.foldr (fn (exp, (stms, ids)) =>
				  let
				      val (stms', id) =
					  unfoldTerm (exp, Goto stms)
				  in
				      (stms', id::ids)
				  end) (rest, nil) exps
	    in
		(stms, O.TupArgs (Vector.fromList ids))
	    end
	  | unfoldArgs (ProdExp (_, expFields), rest, true) =
	    let
		val (stms, labelIdList) =
		    Vector.foldr (fn (Field (_, Lab (_, label), exp),
				      (stms, labelIdList)) =>
				  let
				      val (stms', id) =
					  unfoldTerm (exp, Goto stms)
				  in
				      (stms', (label, id)::labelIdList)
				  end) (rest, nil) expFields
	    in
		case LabelSort.sort labelIdList of
		    (labelIdVec, LabelSort.Tup _) =>
			(stms, O.TupArgs (Vector.map #2 labelIdVec))
		  | (labelIdVec, LabelSort.Prod) =>
			(stms, O.ProdArgs labelIdVec)
	    end
	  | unfoldArgs (exp, rest, _) =
	    let
		val (stms, id) = unfoldTerm (exp, Goto rest)
	    in
		(stms, O.OneArg id)
	    end
	and translateExp (LitExp (info, lit), f, cont) =
	    f (O.LitExp (id_info info, lit))::translateCont cont
	  | translateExp (PrimExp (info, name), f, cont) =
	    f (O.PrimExp (id_info info, name))::translateCont cont
	  | translateExp (NewExp (info, isNAry), f, cont) =
	    f (O.NewExp (id_info info))::translateCont cont
	  | translateExp (VarExp (info, longid), f, cont) =
	    let
		val (stms, id, _) = translateLongid longid
	    in
		stms @ f (O.VarExp (id_info info, id))::translateCont cont
	    end
	  | translateExp (TagExp (info, Lab (_, label), exp, isNAry),
			  f, cont) =
	    let
		val conArity = makeConArity (#typ (infoExp exp), isNAry)
	    in
		if isSome conArity then
		    let
			val r = ref NONE
			val rest = [O.IndirectStm (stm_info (#region info), r)]
			val (stms, args) = unfoldArgs (exp, rest, isNAry)
			val (_, n) = labelToIndex (#typ info, label)
			val (stms', exp') =
			    tagAppExp (info, label, n, args, conArity)
		    in
			r := SOME (stms' @ f exp'::translateCont cont); stms
		    end
		else
		    f (O.TagExp (id_info info, label,
				 #2 (labelToIndex (#typ info, label))))::
		    translateCont cont
	    end
	  | translateExp (ConExp (info, longid, exp, isNAry), f, cont) =
	    let
		val conArity = makeConArity (#typ (infoExp exp), isNAry)
	    in
		if isSome conArity then
		    let
			val r = ref NONE
			val rest = [O.IndirectStm (stm_info (#region info), r)]
			val (stms2, args) = unfoldArgs (exp, rest, isNAry)
			val (stms1, id1, _) = translateLongid longid
			val (stms', exp') =
			    conAppExp (info, O.Con id1, args, conArity)
		    in
			r := SOME (stms' @ f exp'::translateCont cont);
			stms1 @ stms2
		    end
		else
		    let
			val (stms, id, _) = translateLongid longid
		    in
			stms @ f (O.ConExp (id_info info, O.Con id))::
			translateCont cont
		    end
	    end
	  | translateExp (RefExp (info, exp), f, cont) =
	    let
		val r = ref NONE
		val rest = [O.IndirectStm (stm_info (#region info), r)]
		val (stms2, id) = unfoldTerm (exp, Goto rest)
	    in
		(r := SOME (f (O.RefAppExp (id_info info, id))::
			    translateCont cont);
		 stms2)
	    end
	  | translateExp (TupExp (info, exps), f, cont) =
	    let
		val r = ref NONE
		val rest = [O.IndirectStm (stm_info (#region info), r)]
		val (stms, ids) =
		    Vector.foldr (fn (exp, (stms, ids)) =>
				  let
				      val (stms', id) =
					  unfoldTerm (exp, Goto stms)
				  in
				      (stms', id::ids)
				  end) (rest, nil) exps
	    in
		r := SOME (f (O.TupExp (id_info info, Vector.fromList ids))::
			   translateCont cont);
		stms
	    end
	  | translateExp (ProdExp (info, expFields), f, cont) =
	    let
		val r = ref NONE
		val rest = [O.IndirectStm (stm_info (#region info), r)]
		val (stms, fields) =
		    Vector.foldr (fn (Field (_, Lab (_, label), exp),
				      (stms, fields)) =>
				  let
				      val (stms', id) =
					  unfoldTerm (exp, Goto stms)
				  in
				      (stms', (label, id)::fields)
				  end) (rest, nil) expFields
		val exp' =
		    case LabelSort.sort fields of
			(fields', LabelSort.Tup _) =>
			    O.TupExp (id_info info, Vector.map #2 fields')
		      | (fields', LabelSort.Prod) =>
			    O.ProdExp (id_info info, fields')
	    in
		r := SOME (f exp'::translateCont cont); stms
	    end
	  | translateExp (SelExp (info, Lab (_, label), exp), f, cont) =
	    let
		val r = ref NONE
		val rest = [O.IndirectStm (stm_info (#region info), r)]
		val (stms2, id2) = unfoldTerm (exp, Goto rest)
		val (prod, n) = labelToIndex (#typ (infoExp exp), label)
	    in
		(r := SOME (f (O.SelAppExp (id_info info, prod, label, n,
					    id2))::translateCont cont);
		 stms2)
	    end
	  | translateExp (VecExp (info, exps), f, cont) =
	    let
		val r = ref NONE
		val rest = [O.IndirectStm (stm_info (#region info), r)]
		val (stms, ids) =
		    Vector.foldr (fn (exp, (stms, ids)) =>
				  let
				      val (stms', id) =
					  unfoldTerm (exp, Goto stms)
				  in
				      (stms', id::ids)
				  end) (rest, nil) exps
	    in
		r := SOME (f (O.VecExp (id_info info, (Vector.fromList ids)))::
			   translateCont cont);
		stms
	    end
	  | translateExp (FunExp (info, matches), f, cont) =
	    let
		val matches' =
		    Vector.map (fn Match (info, pat, exp) =>
				let
				    val region = #region info
				    fun return exp' =
					O.ReturnStm (stm_info region, exp')
				in
				    (#region (infoExp exp), pat,
				     translateExp (exp, return, Goto nil))
				end) matches
		val region = #1 (Vector.sub (matches', 0))
		val errStms = raisePrim (region, "General.Match")
		val (args, graph, mapping, consequents) =
		    buildFunArgs (matches', errStms)
		val (body, _) = translateGraph (graph, mapping)
	    in
		checkReachability consequents;
		f (O.FunExp (id_info info, Stamp.new (), nil, args, body))::
		translateCont cont
	    end
	  | translateExp (AppExp (info, exp1, exp2), f, cont) =
	    let
		val r = ref NONE
		val rest = [O.IndirectStm (stm_info (#region info), r)]
		val (stms2, args) = unfoldArgs (exp2, rest, true)
		val (stms1, id1) = unfoldTerm (exp1, Goto stms2)
	    in
		r := SOME (f (O.VarAppExp (id_info info, id1, args))::
			   translateCont cont);
		stms1
	    end
	  | translateExp (AndExp (info, exp1, exp2), f, cont) =
	    let
		val exp3 =
		    TagExp (info, Lab (id_info info, PervasiveType.lab_false),
			    FailExp {region = #region info,
				     typ = PervasiveType.typ_zero},
			    false)
	    in
		translateExp (IfExp (info, exp1, exp2, exp3), f, cont)
	    end
	  | translateExp (OrExp (info, exp1, exp2), f, cont) =
	    let
		val exp3 =
		    TagExp (info, Lab (id_info info, PervasiveType.lab_true),
			    FailExp {region = #region info,
				     typ = PervasiveType.typ_zero},
			    false)
	    in
		translateExp (IfExp (info, exp1, exp3, exp2), f, cont)
	    end
	  | translateExp (IfExp (_, exp1, exp2, exp3), f, cont) =
	    let
		val cont' = Share (ref NONE, cont)
		val stms2 = translateExp (exp2, f, cont')
		val stms3 = translateExp (exp3, f, cont')
	    in
		simplifyIf (exp1, stms2, stms3)
	    end
	  | translateExp (WhileExp (info, exp1, exp2), f, cont) =
	    let
		val r = ref NONE
		val cont' = Goto [O.IndirectStm (stm_info (#region info), r)]
		fun eval exp' =
		    O.ValDec (stm_info (#region (infoExp exp2)),
			      O.Wildcard, exp')
		val info' = infoExp exp1
		val id = freshIntermediateId info'
		val trueBody = translateExp (exp2, eval, cont')
		val falseBody = translateExp (TupExp (info, #[]), f, cont)
		val errorBody = raisePrim (#region info', "General.Match")
		val stms1 =
		    translateIf (info', translateId id,
				 trueBody, falseBody, errorBody)
		val stms2 =
		    translateDec (ValDec (id_info info',
					  VarPat (info', id), exp1),
				  Goto stms1)
		val stms = share stms2
	    in
		r := SOME stms; stms
	    end
	  | translateExp (SeqExp (_, exps), f, cont) =
	    let
		val isLast = ref true
		fun translate (exp, stms) =
		    if !isLast then
			(case stms of
			     nil => ()
			   | _::_ =>
			     raise Crash.Crash "FlatteningPhase.translateExp";
			 isLast := false; translateExp (exp, f, cont))
		    else
			translateExp
			(exp,
			 fn exp' => O.ValDec (stm_info (#region (infoExp exp)),
					      O.Wildcard, exp'),
			 Goto stms)
	    in
		Vector.foldr translate nil exps
	    end
	  | translateExp (CaseExp (info, exp, matches), f, cont) =
	    let
		val cont' = Share (ref NONE, cont)
		val matches' =
		    Vector.map (fn Match (_, pat, exp) =>
				(#region (infoExp exp), pat,
				 translateExp (exp, f, cont'))) matches
		val info = {region = #region info, typ = PervasiveType.typ_exn}
	    in
		simplifyCase (#region info, exp, matches',
			      PrimExp (info, "General.Match"), false)
	    end
	  | translateExp (RaiseExp (info, exp), _, _) =
	    let
		val r = ref NONE
		val rest = [O.IndirectStm (stm_info (#region info), r)]
		val (stms, id) = unfoldTerm (exp, Goto rest)
	    in
		r := SOME [O.RaiseStm (stm_info (#region info), id)]; stms
	    end
	  | translateExp (HandleExp (info, exp, matches), f, cont) =
	    let
		val info' = infoExp exp
		val id' = freshIntermediateId info'
		val stamp = Stamp.new ()
		val cont' =
		    Goto [O.EndHandleStm (stm_info (#region info), stamp)]
		fun f' exp' =
		    O.ValDec (stm_info (#region info'),
			      O.IdDef (translateId id'), exp')
		val tryBody = translateExp (exp, f', cont')
		val catchInfo = {region = #region info,
				 typ = PervasiveType.typ_exn}
		val catchId = freshIntermediateId catchInfo
		val catchVarExp =
		    VarExp (catchInfo, ShortId (catchInfo, catchId))
		val matches' =
		    Vector.map (fn Match (_, pat, exp) =>
			      (#region (infoExp exp), pat,
			       translateExp (exp, f', cont')))
		    matches
		val catchBody =
		    simplifyCase (#region info, catchVarExp, matches',
				  catchVarExp, true)
		val contBody =
		    translateExp (VarExp (info', ShortId (info', id')),
				  f, cont)
	    in
		[O.HandleStm (stm_info (#region info), tryBody,
			      O.IdDef (translateId catchId),
			      catchBody, contBody, stamp)]
	    end
	  | translateExp (FailExp info, f, cont) =
	    let
		val region = #region info
		val info' = {region = region}
		val unitId = O.freshId info'
		val holeId = O.freshId info'
		val exnId = O.freshId info'
	    in
		O.ValDec (stm_info region, O.IdDef unitId,
			  O.TupExp (info', #[]))::
		O.ValDec (stm_info region, O.IdDef holeId,
			  O.PrimAppExp (info', "Hole.hole", #[unitId]))::
		O.ValDec (stm_info region, O.IdDef exnId,
			  O.PrimExp (info', "Hole.Hole"))::
		O.ValDec (stm_info region, O.Wildcard,
			  O.PrimAppExp (info', "Hole.fail",
					#[holeId, exnId]))::
		f (O.VarExp (info', holeId))::translateCont cont
	    end
	  | translateExp (LazyExp (info as {region, typ}, exp), f, cont) =
	    let
		val r = ref NONE
		val rest = [O.IndirectStm (stm_info region, r)]
		val funInfo = {region = region,
			       typ = Type.inArrow (Type.inTuple #[], typ)}
		val pat = JokPat {region = region, typ = Type.inTuple #[]}
		val funExp =
		    FunExp (funInfo, #[Match (id_info info, pat, exp)])
		val (stms, id) = unfoldTerm (funExp, Goto rest)
	    in
		(r := SOME (f (O.PrimAppExp (id_info info, "Future.byneed",
					     #[id]))::translateCont cont);
		 stms)
	    end
	  | translateExp (LetExp (_, decs, exp), f, cont) =
	    let
		val stms = translateExp (exp, f, cont)
	    in
		translateCont (Decs (Vector.toList decs, Goto stms))
	    end
	  | translateExp (UpExp (_, exp), f, cont) =
	    translateExp (exp, f, cont)
	and simplifyIf (AndExp (_, exp1, exp2), thenStms, elseStms) =
	    let
		val elseStms' = share elseStms
		val thenStms' = simplifyIf (exp2, thenStms, elseStms')
	    in
		simplifyIf (exp1, thenStms', elseStms')
	    end
	  | simplifyIf (OrExp (_, exp1, exp2), thenStms, elseStms) =
	    let
		val thenStms' = share thenStms
		val elseStms' = simplifyIf (exp2, thenStms', elseStms)
	    in
		simplifyIf (exp1, thenStms', elseStms')
	    end
	  | simplifyIf (exp, thenStms, elseStms) =
	    let
		val info = infoExp exp
		val r = ref NONE
		val rest = [O.IndirectStm (stm_info (#region info), r)]
		val (stms, id) = unfoldTerm (exp, Goto rest)
		val errStms = raisePrim (#region info, "General.Match")
		val stms1 = translateIf (info, id, thenStms, elseStms, errStms)
	    in
		r := SOME stms1; stms
	    end
	and checkReachability consequents =
	    List.app (fn (region, ref bodyOpt) =>
		      if isSome bodyOpt then ()
		      else Error.warn (region, "unreachable expression"))
	    consequents
	and simplifyCase (region, exp, matches, raiseExp, isReraise) =
	    let
		val r = ref NONE
		val rest = [O.IndirectStm (stm_info region, r)]
		val (stms, id) = unfoldTerm (exp, Goto rest)
		val r' = ref NONE
		val rest' = [O.IndirectStm (stm_info region, r')]
		val (errStms, raiseId) = unfoldTerm (raiseExp, Goto rest')
		val (graph, consequents) = buildGraph (matches, errStms)
		val (body, _) = translateGraph (graph, [(nil, id)])
	    in
		r := SOME body;
		r' := SOME (if isReraise then
				[O.ReraiseStm (stm_info region, raiseId)]
			    else [O.RaiseStm (stm_info region, raiseId)]);
		checkReachability consequents;
		stms
	    end
	and translateGraph (Node (pos, test, ref thenGraph, ref elseGraph,
				  status as ref (Cooked (_, _))), mapping) =
	    let
		val (body, mapping') =
		    translateNode (pos, test, thenGraph, elseGraph, mapping)
		val stms = share body
	    in
		status := Translated stms; (stms, mapping')
	    end
	  | translateGraph (Node (_, _, _, _, ref (Translated stms)),
			    mapping) =
	    (stms, mapping)
	  | translateGraph (Leaf (stms, stmsOptRef as ref NONE), mapping) =
	    let
		val stms' = share stms
	    in
		stmsOptRef := SOME stms'; (stms', mapping)
	    end
	  | translateGraph (Leaf (_, ref (SOME stms)), mapping) =
	    (stms, mapping)
	  | translateGraph (_, _) =
	    raise Crash.Crash "FlatteningPhase.translateGraph"
	and translateNode (pos, RefTest, thenGraph, _, mapping) =
	    let
		val (idDef, mapping') =
		    adjoin (LABEL (Label.fromString "ref")::pos, mapping)
		val id = lookup (pos, mapping)
		val (thenBody, mapping'') =
		    translateGraph (thenGraph, mapping')
	    in
		(O.RefAppDec (stm_info Source.nowhere, idDef, id)::thenBody,
		 mapping'')
	    end
	  | translateNode (pos, TupTest n, thenGraph, _, mapping) =
	    let
		val (idDefs, mapping') = translateTupArgs (n, pos, mapping)
		val id = lookup (pos, mapping)
		val (thenBody, mapping'') =
		    translateGraph (thenGraph, mapping')
	    in
		(O.TupDec (stm_info Source.nowhere, idDefs, id)::thenBody,
		 mapping'')
	    end
	  | translateNode (pos, ProdTest labels, thenGraph, _, mapping) =
	    let
		val (labelIdDefList, mapping') =
		    translateProdArgs (labels, pos, mapping)
		val id = lookup (pos, mapping)
		val (thenBody, mapping'') =
		    translateGraph (thenGraph, mapping')
	    in
		(O.ProdDec (stm_info Source.nowhere, labelIdDefList, id)::
		 thenBody, mapping'')
	    end
	  | translateNode (_, GuardTest (mapping0, exp),
			   thenGraph, elseGraph, mapping) =
	    let
		val info = infoExp exp
		val r = ref NONE
		val rest = [O.IndirectStm (stm_info (#region info), r)]
		val subst = mappingsToSubst (mapping0, mapping)
		val (stms, id) = unfoldTerm (substExp (exp, subst), Goto rest)
		val (thenStms, mapping') = translateGraph (thenGraph, mapping)
		val (elseStms, mapping'') =
		    translateGraph (elseGraph, mapping')
		val errStms = raisePrim (#region info, "General.Match")
		val stms1 = translateIf (info, id, thenStms, elseStms, errStms)
	    in
		r := SOME stms1; (stms, mapping'')
	    end
	  | translateNode (_, DecTest (mapping0, decs),
			   thenGraph, _, mapping) =
	    let
		val (thenBody, mapping') = translateGraph (thenGraph, mapping)
		val subst = mappingsToSubst (mapping0, mapping)
		val cont =
		    Decs (Vector.foldr (fn (dec, rest) =>
					substDec (dec, subst)::rest) nil decs,
			  Goto thenBody)
	    in
		(translateCont cont, mapping')
	    end
	  | translateNode (pos, LitTest lit, thenGraph, elseGraph, mapping) =
	    let
		val id = lookup (pos, mapping)
		val (thenBody, mapping') = translateGraph (thenGraph, mapping)
		val tests = O.LitTests #[(lit, thenBody)]
		val (elseBody, mapping'') =
		    translateGraph (elseGraph, mapping')
	    in
		([O.TestStm (stm_info Source.nowhere, id, tests, elseBody)],
		 mapping'')
	    end
	  | translateNode (pos, TagTest (label, n, NONE, _),
			   thenGraph, elseGraph, mapping) =
	    let
		val id = lookup (pos, mapping)
		val (thenBody, mapping') = translateGraph (thenGraph, mapping)
		val tests = O.TagTests #[(label, n, NONE, thenBody)]
		val (elseBody, mapping'') =
		    translateGraph (elseGraph, mapping')
	    in
		([O.TestStm (stm_info Source.nowhere, id, tests, elseBody)],
		 mapping'')
	    end
	  | translateNode (pos, TagTest (label, n, SOME args, conArity),
			   thenGraph, elseGraph, mapping) =
	    let
		val id = lookup (pos, mapping)
		val (idDefArgs, mapping') =
		    translateArgs (args, LABEL label::pos, mapping)
		val (thenBody, mapping'') =
		    translateGraph (thenGraph, mapping')
		val tests =
		    tagAppTest (label, n, idDefArgs, conArity, thenBody)
		val (elseBody, mapping''') =
		    translateGraph (elseGraph, mapping'')
	    in
		([O.TestStm (stm_info Source.nowhere, id, tests, elseBody)],
		 mapping''')
	    end
	  | translateNode (pos, ConTest (longid, NONE, _),
			   thenGraph, elseGraph, mapping) =
	    let
		val id = lookup (pos, mapping)
		val (stms, id', _) = translateLongid longid
		val (thenBody, mapping') = translateGraph (thenGraph, mapping)
		val tests = O.ConTests #[(O.Con id', NONE, thenBody)]
		val (elseBody, mapping'') =
		    translateGraph (elseGraph, mapping')
	    in
		(stms @ [O.TestStm (stm_info Source.nowhere, id, tests,
				    elseBody)], mapping'')
	    end
	  | translateNode (pos, ConTest (longid, SOME args, conArity),
			   thenGraph, elseGraph, mapping) =
	    let
		val id = lookup (pos, mapping)
		val (stms, id', _) = translateLongid longid
		val (idDefArgs, mapping') =
		    translateArgs (args, longidToSelector longid::pos, mapping)
		val (thenBody, mapping'') =
		    translateGraph (thenGraph, mapping')
		val tests =
		    conAppTest (O.Con id', idDefArgs, conArity, thenBody)
		val (elseBody, mapping''') =
		    translateGraph (elseGraph, mapping'')
	    in
		(stms @ [O.TestStm (stm_info Source.nowhere, id, tests,
				    elseBody)], mapping''')
	    end
	  | translateNode (pos, VecTest n, thenGraph, elseGraph, mapping) =
	    let
		val id = lookup (pos, mapping)
		val (idDefs, mapping') = translateTupArgs (n, pos, mapping)
		val (thenBody, mapping'') =
		    translateGraph (thenGraph, mapping')
		val tests = O.VecTests #[(idDefs, thenBody)]
		val (elseBody, mapping''') =
		    translateGraph (elseGraph, mapping'')
	    in
		([O.TestStm (stm_info Source.nowhere, id, tests, elseBody)],
		 mapping''')
	    end
	and translateArgs (O.OneArg _, pos, mapping) =
	    let
		val (idDef, mapping') = adjoin (pos, mapping)
	    in
		(O.OneArg idDef, mapping')
	    end
	  | translateArgs (O.TupArgs xs, pos, mapping) =
	    let
		val (idDefs, mapping') =
		    translateTupArgs (Vector.length xs, pos, mapping)
	    in
		(O.TupArgs idDefs, mapping')
	    end
	  | translateArgs (O.ProdArgs labelXVec, pos, mapping) =
	    let
		val (labelIdDefVec, mapping') =
		    translateProdArgs (Vector.map #1 labelXVec, pos, mapping)
	    in
		(O.ProdArgs labelIdDefVec, mapping')
	    end
	and translateTupArgs (n, pos, mapping) =
	    let
		val (idDefs, mapping) = translateTupArgs' (n, pos, mapping)
	    in
		(Vector.fromList idDefs, mapping)
	    end
	and translateTupArgs' (0, _, mapping) = (nil, mapping)
	  | translateTupArgs' (n, pos, mapping) =
	    let
		val (idDefs, mapping) = translateTupArgs' (n - 1, pos, mapping)
		val (idDef, mapping) =
		    adjoin (LABEL (Label.fromInt n)::pos, mapping)
	    in
		(idDef::idDefs, mapping)
	    end
	and translateProdArgs (labels, pos, mapping) =
	    let
		val (labelIdDefList, mapping) =
		    Vector.foldr
		    (fn (label, (labelIdDefList, mapping)) =>
		     let
			 val (idDef, mapping) =
			     adjoin (LABEL label::pos, mapping)
		     in
			 ((label, idDef)::labelIdDefList, mapping)
		     end) (nil, mapping) labels
	    in
		(Vector.fromList labelIdDefList, mapping)
	    end

	fun translate () (desc, (imports, (exportExp, sign))) =
	    let
		fun export exp =
		    O.ExportStm (stm_info (#region (infoExp exportExp)), exp)
		val imports' =
		    Vector.map (fn (id, sign, url) =>
				(O.IdDef (translateId id), sign, url)) imports
	    in
		(imports', (translateExp (exportExp, export, Goto nil), sign))
	    end
    end
