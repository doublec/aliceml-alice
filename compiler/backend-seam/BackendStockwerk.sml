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

structure BackendStockwerk: PHASE =
    struct
	structure C = EmptyContext
	structure I = FlatGrammar
	structure O = Pickle

	open I
	open Environment

	fun translateLit (IntLit i) = O.Int i
	  | translateLit (WordLit w) = O.Word w
	  | translateLit (CharLit c) = O.Char c
	  | translateLit (StringLit s) = O.String s
	  | translateLit (RealLit r) = O.Real r

	fun translateId (id, env) = lookup (env, id)

	fun translateIds (ids, env) =
	    Vector.map (fn id => lookup (env, id)) ids

	fun translateIdDef (IdDef id, env) = O.IdDef (declare (env, id))
	  | translateIdDef (Wildcard, _) = O.Wildcard

	fun translateCon (Con id, env) = O.Con (lookup (env, id))
	  | translateCon (StaticCon stamp, _) =
	    O.StaticCon (O.Constructor stamp)

	fun translateArgs f (OneArg idDef, env) =
	    O.OneArg (f (idDef, env))
	  | translateArgs f (TupArgs idDefs, env) =
	    O.TupArgs (Vector.map (fn idDef => f (idDef, env)) idDefs)
	  | translateArgs f (ProdArgs labelIdDefList, env) =
	    translateArgs f (TupArgs (Vector.map #2 labelIdDefList), env)

	fun argsToVector (OneArg x) = #[x]
	  | argsToVector (TupArgs xs) = xs
	  | argsToVector (ProdArgs labelXList) = Vector.map #2 labelXList

	fun isId (O.Local i, id) = i = id
	  | isId (O.Global _, _) = false

	fun isIdInVec (idRefs, id) =
	    Vector.exists (fn idRef => isId (idRef, id)) idRefs

	fun isIdInArgs (O.OneArg idRef, id) = isId (idRef, id)
	  | isIdInArgs (O.TupArgs idRefs, id) = isIdInVec (idRefs, id)

	datatype detup_result =
	    USED
	  | KILLED
	  | DECONSTRUCTED of O.idDef vector

	fun detup (O.Kill (ids, instr), id) =
	    if Vector.exists (fn id' => id = id') ids then KILLED
	    else detup (instr, id)
	  | detup (O.PutConst (_, _, instr), id) = detup (instr, id)
	  | detup (O.PutVar (_, idRef, instr), id) =
	    if isId (idRef, id) then USED else detup (instr, id)
	  | detup (O.PutNew (_, instr), id) = detup (instr, id)
	  | detup (O.PutTag (_, _, idRefs, instr), id) =
	    if isIdInVec (idRefs, id) then USED else detup (instr, id)
	  | detup (O.PutCon (_, _, idRefs, instr), id) =
	    if isIdInVec (idRefs, id) then USED else detup (instr, id)
	  | detup (O.PutRef (_, idRef, instr), id) =
	    if isId (idRef, id) then USED else detup (instr, id)
	  | detup (O.PutTup (_, idRefs, instr), id) =
	    if isIdInVec (idRefs, id) then USED else detup (instr, id)
	  | detup (O.PutVec (_, idRefs, instr), id) =
	    if isIdInVec (idRefs, id) then USED else detup (instr, id)
	  | detup (O.PutFun (_, idRefs, _, instr), id) =
	    if isIdInVec (idRefs, id) then USED else detup (instr, id)
	  | detup (O.AppPrim (_, _, idRefs, instrOpt), id) =
	    if isIdInVec (idRefs, id) then USED
	    else
		(case instrOpt of
		     SOME instr => detup (instr, id)
		   | NONE => KILLED)
	  | detup (O.AppVar (_, idRef, idRefArgs, instrOpt), id) =
	    if isId (idRef, id) orelse isIdInArgs (idRefArgs, id) then USED
	    else
		(case instrOpt of
		     SOME instr => detup (instr, id)
		   | NONE => KILLED)
	  | detup (O.GetRef (_, idRef, instr), id) =
	    if isId (idRef, id) then USED else detup (instr, id)
	  | detup (O.GetTup (idDefs, idRef, instr), id) =
	    if isId (idRef, id) then
		case detup (instr, id) of
		    (USED | DECONSTRUCTED _) => USED
		  | KILLED => DECONSTRUCTED idDefs
	    else detup (instr, id)
	  | detup (O.Raise idRef, id) =
	    if isId (idRef, id) then USED else KILLED
	  | detup (O.Try (_, _, _), _) = USED
	  | detup (O.EndTry _, _) = USED
	  | detup (O.EndHandle _, _) = USED
	  | detup (O.IntTest (_, _, _), _) = USED
	  | detup (O.RealTest (_, _, _), _) = USED
	  | detup (O.StringTest (_, _, _), _) = USED
	  | detup (O.TagTest (_, _, _, _), _) = USED
	  | detup (O.ConTest (_, _, _, _), _) = USED
	  | detup (O.VecTest (_, _, _), _) = USED
	  | detup (O.Return idRefArgs, id) =
	    if isIdInArgs (idRefArgs, id) then USED else KILLED

	fun translateBody (stm::stms, env) =
	    let
		val instr =
		    case stms of
			_::_ =>
			    translateDec (stm, translateBody (stms, env), env)
		      | nil => translateStm (stm, env)
	    in
		case #liveness (infoStm stm) of
		    ref (Kill set) =>
			let
			    val idRefs =
				StampSet.fold (fn (stamp, rest) =>
					       lookupStamp (env, stamp)::rest)
				nil set
			    val ids =
				List.mapPartial (fn O.Local i => SOME i
						  | O.Global _ => NONE) idRefs
			in
			    O.Kill (Vector.fromList ids, instr)
			end
		      | ref _ => instr
	    end
	  | translateBody (nil, _) =
	    raise Crash.Crash "BackendStockwerk.translateBody"
	and translateDec (ValDec (_, IdDef id, exp), instr, env) =
	    translateExp (exp, declare (env, id), instr, env)
	  | translateDec (ValDec (_, Wildcard, exp), instr, env) =
	    translateIgnore (exp, instr, env)

(*--** MISSING
	  | RecDec of stm_info * (idDef * exp) vector
	    (* all ids distinct *)
*)

	  | translateDec (RefAppDec (_, IdDef id, id'), instr, env) =
	    O.GetRef (declare (env, id), translateId (id', env), instr)
	  | translateDec (RefAppDec (_, Wildcard, id), instr, env) =
	    let
		val id' = lookup (env, id)
	    in
		O.AppPrim (O.Wildcard, "Future.await", #[id'], SOME instr)
	    end
	  | translateDec (TupDec (_, idDefs, id), instr, env) =
	    let
		fun f id = translateIdDef (id, env)
	    in
		O.GetTup (Vector.map f idDefs, lookup (env, id), instr)
	    end
	  | translateDec (ProdDec (info, labelIdDefVec, id), instr, env) =
	    translateDec (TupDec (info, Vector.map #2 labelIdDefVec, id),
			  instr, env)
	  | translateDec (_, _, _) =
	    raise Crash.Crash "BackendStockwerk.translateDec"
	and translateStm (RaiseStm (_, id), env) =
	    O.Raise (lookup (env, id))
	  | translateStm (ReraiseStm (_, id), env) = (*--** do better *)
	    O.Raise (lookup (env, id))

(*--** MISSING
	  | HandleStm of stm_info * body * idDef * body * body * stamp
	  | EndHandleStm of stm_info * stamp
	  | TestStm of stm_info * id * tests * body
	  | SharedStm of stm_info * body * stamp   (* used at least twice *)
*)

	  | translateStm (ReturnStm (_, exp), env) =
	    let
		val id = fresh env
	    in
		translateExp (exp, id, O.Return (O.OneArg (O.Local id)), env)
	    end
	  | translateStm (IndirectStm (_, ref (SOME stms)), env) =
	    translateBody (stms, env)
	  | translateStm (ExportStm (info, exp), env) =
	    translateStm (ReturnStm (info, exp), env)
	  | translateStm (_, _) =
	    raise Crash.Crash "BackendStockwerk.translateStm"
	and translateExp (LitExp (_, lit), id, instr, _) =
	    O.PutConst (id, translateLit lit, instr)
	  | translateExp (PrimExp (_, name), id, instr, _) =
	    O.PutConst (id, O.Prim name, instr)
	  | translateExp (NewExp _, id, instr, _) = O.PutNew (id, instr)
	  | translateExp (VarExp (_, id'), id, instr, env) =
	    O.PutVar (id, lookup (env, id'), instr)
	  | translateExp (TagExp (_, _, tag), id, instr, _) =
	    O.PutConst (id, O.Int (LargeInt.fromInt tag), instr)
	  | translateExp (ConExp (_, Con id'), id, instr, env) =
	    O.PutVar (id, lookup (env, id'), instr)
	  | translateExp (ConExp (_, StaticCon s), id, instr, _) =
	    O.PutConst (id, O.Constructor s, instr)
	  | translateExp (TupExp (_, ids), id, instr, env) =
	    O.PutTup (id, translateIds (ids, env), instr)
	  | translateExp (ProdExp (info, labelIdVec), id, instr, env) =
	    translateExp (TupExp (info, Vector.map #2 labelIdVec),
			  id, instr, env)
	  | translateExp (VecExp (_, ids), id, instr, env) =
	    O.PutVec (id, translateIds (ids, env), instr)
	  | translateExp (FunExp (_, _, _, args, body), id, instr, env) =
	    let
		val _ = startFn env
		val args' = translateArgs translateIdDef (args, env)
		val bodyInstr = translateBody (body, env)
		val globals = endFn env
		val function =
		    O.Function (Vector.length globals, args', bodyInstr)
	    in
		O.PutFun (id, translateIds (globals, env), function, instr)
	    end
	  | translateExp (PrimAppExp (_, name, ids), id, instr, env) =
	    O.AppPrim (O.IdDef id, name, translateIds (ids, env), SOME instr)
	  | translateExp (VarAppExp (_, id, args), id', instr, env) =
	    let
		val returnArgs =
		    case detup (instr, id') of
			DECONSTRUCTED idDefs => O.TupArgs idDefs
		      | USED => O.OneArg (O.IdDef id')
		      | KILLED => O.OneArg O.Wildcard
	    in
		O.AppVar (returnArgs, lookup (env, id),
			  translateArgs translateId (args, env), SOME instr)
	    end
	  | translateExp (TagAppExp (_, _, tag, args), id, instr, env) =
	    O.PutTag (id, tag, translateIds (argsToVector args, env), instr)
	  | translateExp (ConAppExp (_, con, args), id, instr, env) =
	    O.PutCon (id, translateCon (con, env),
		      translateIds (argsToVector args, env), instr)
	  | translateExp (RefAppExp (_, id), id', instr, env) =
	    O.PutRef (id', lookup (env, id), instr)
	  | translateExp (SelAppExp (_, Tuple n, _, index, id),
			  id', instr, env) =
	    let
		fun wild _ = O.Wildcard
	    in
		O.GetTup (Vector.fromList
			  (List.tabulate (index, wild) @
			   O.IdDef id'::List.tabulate (n - index - 1, wild)),
			  lookup (env, id), instr)
	    end
	  | translateExp (FunAppExp (info, id, _, args), id', instr, env) =
	    (*--** support direct call; multiple return values *)
	    translateExp (VarAppExp (info, id, args), id', instr, env)
	and translateIgnore (LitExp (_, _), instr, _) = instr
	  | translateIgnore (PrimExp (_, _), instr, _) = instr
	  | translateIgnore (NewExp _, instr, _) = instr
	  | translateIgnore (VarExp (_, _), instr, _) = instr
	  | translateIgnore (TagExp (_, _, _), instr, _) = instr
	  | translateIgnore (ConExp (_, _), instr, _) = instr
	  | translateIgnore (TupExp (_, _), instr, _) = instr
	  | translateIgnore (ProdExp (_, _), instr, _) = instr
	  | translateIgnore (VecExp (_, _), instr, _) = instr
	  | translateIgnore (FunExp (_, _, _, _, _), instr, _) = instr
	  | translateIgnore (PrimAppExp (_, name, ids), instr, env) =
	    O.AppPrim (O.Wildcard, name, translateIds (ids, env), SOME instr)
	  | translateIgnore (VarAppExp (_, id, args), instr, env) =
	    O.AppVar (O.OneArg O.Wildcard, lookup (env, id),
		      translateArgs translateId (args, env), SOME instr)
	  | translateIgnore (TagAppExp (_, _, _, _), instr, _) = instr
	  | translateIgnore (ConAppExp (_, Con id, _), instr, env) =
	    O.AppPrim (O.Wildcard, "Future.await", #[lookup (env, id)],
		       SOME instr)
	  | translateIgnore (ConAppExp (_, StaticCon _, _), instr, _) = instr
	  | translateIgnore (RefAppExp (_, _), instr, _) = instr
	  | translateIgnore (SelAppExp (_, _, _, _, id), instr, env) =
	    O.AppPrim (O.Wildcard, "Future.await", #[lookup (env, id)],
		       SOME instr)
	  | translateIgnore (FunAppExp (info, id, _, args), instr, env) =
	    (*--** support direct call  *)
	    translateIgnore (VarAppExp (info, id, args), instr, env)

	fun translate () (desc, component) = O.Int 0 (*--** *)
    end
