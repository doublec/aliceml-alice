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

structure SimplifyRec :> SIMPLIFY_REC =
    struct
	structure I = IntermediateGrammar

	open I
	open IntermediateAux

	type constraint = longid * longid
	type binding = id * exp
	type alias = id * id * exp_info

	datatype pat =
	    JokPat of pat_info
	  | LitPat of pat_info * lit
	  | VarPat of pat_info * id
	  | TagPat of pat_info * lab * pat * bool
	  | ConPat of pat_info * longid * pat * bool
	  | RefPat of pat_info * pat
	  | TupPat of pat_info * pat vector
	  | ProdPat of pat_info * pat field vector
	  | VecPat of pat_info * pat vector
	  | AsPat of pat_info * id * pat

	fun infoPat (JokPat info) = info
	  | infoPat (LitPat (info, _)) = info
	  | infoPat (VarPat (info, _)) = info
	  | infoPat (TagPat (info, _, _, _)) = info
	  | infoPat (ConPat (info, _, _, _)) = info
	  | infoPat (RefPat (info, _)) = info
	  | infoPat (TupPat (info, _)) = info
	  | infoPat (ProdPat (info, _)) = info
	  | infoPat (VecPat (info, _)) = info
	  | infoPat (AsPat (info, _, _)) = info

	structure FieldSort =
	    MakeLabelSort(type 'a t = 'a field
			  fun get (Field (_, Lab (_, label), _)) = label)

	fun select (Field (_, Lab (_, s), x)::fieldr, s') =
	    if s = s' then SOME x else select (fieldr, s')
	  | select (nil, _) = NONE

	fun unalias (JokPat _) = (nil, NONE)
	  | unalias (VarPat (_, id)) = ([id], NONE)
	  | unalias (AsPat (_, id, pat)) =
	    let
		val (ids, patOpt) = unalias pat
	    in
		(id::ids, patOpt)
	    end
	  | unalias pat = (nil, SOME pat)

	fun mkRefTyp typ =
	    Type.inArrow (typ, Type.inApply (PervasiveType.typ_ref, typ))

	fun patToExp (JokPat info) =
	    let
		val id = freshIntermediateId info
	    in
		(VarPat (info, id), VarExp (info, ShortId (info, id)))
	    end
	  | patToExp (pat as LitPat (info, lit)) = (pat, LitExp (info, lit))
	  | patToExp (pat as VarPat (info, id)) =
	    (pat, VarExp (info, ShortId (info, id)))
	  | patToExp (TagPat (info, lab, pat, isNAry)) =
	    let
		val (pat', exp') = patToExp pat
	    in
		(TagPat (info, lab, pat', isNAry),
		 TagExp (info, lab, exp', isNAry))
	    end
	  | patToExp (ConPat (info, longid, pat, isNAry)) =
	    let
		val (pat', exp') = patToExp pat
	    in
		(ConPat (info, longid, pat', isNAry),
		 ConExp (info, longid, exp', isNAry))
	    end
	  | patToExp (RefPat (info, pat)) =
	    let
		val (pat', exp') = patToExp pat
		val info' =
		    {region = #region info,
		     typ = mkRefTyp (#typ (infoPat pat))}
	    in
		(RefPat (info, pat'), RefExp (info, exp'))
	    end
	  | patToExp (TupPat (info, pats)) =
	    let
		val (pats', exps') =
		    VectorPair.unzip (Vector.map patToExp pats)
	    in
		(TupPat (info, pats'), TupExp (info, exps'))
	    end
	  | patToExp (ProdPat (info, patFields)) =
	    let
		val (patFields', expFields') =
		    Vector.foldr (fn (Field (info, label, pat),
				      (patFields, expFields)) =>
				  let
				      val (pat', exp) = patToExp pat
				  in
				      (Field (info, label, pat')::patFields,
				       Field (info, label, exp)::expFields)
				  end) (nil, nil) patFields
	    in
		(ProdPat (info, Vector.fromList patFields'),
		 ProdExp (info, Vector.fromList expFields'))
	    end
	  | patToExp (VecPat (info, pats)) =
	    let
		val (pats', exps') =
		    VectorPair.unzip (Vector.map patToExp pats)
	    in
		(VecPat (info, pats'), VecExp (info, exps'))
	    end
	  | patToExp (pat as AsPat (info, id, _)) =
	    (pat, VarExp (info, ShortId (info, id)))

	fun derec' (JokPat _, exp) = (nil, [(nil, exp)])
	  | derec' (LitPat (info, lit1), LitExp (_, lit2)) =
	    if lit1 = lit2 then (nil, nil)
	    else Error.error (#region info, "pattern never matches")
	  | derec' (VarPat (_, id), exp) = (nil, [([id], exp)])
	  | derec' (TagPat (info, Lab (_, label1), pat, _),
		    TagExp (_, Lab (_, label2), exp, true)) =
	    let
		val (constraints, idsExpList) = derec' (pat, exp)
	    in
		if label1 = label2 then (constraints, idsExpList)
		else Error.error (#region info, "pattern never matches")
	    end
	  | derec' (ConPat (_, longid1, pat, _),
		    ConExp (_, longid2, exp, true)) =
	    let
		val (constraints, idsExpList) = derec' (pat, exp)
	    in
		((longid1, longid2)::constraints, idsExpList)
	    end
	  | derec' (RefPat (_, pat), AppExp (_, RefExp _, exp)) =
	    derec' (pat, exp)
	  | derec' (TupPat (_, pats), TupExp (_, exps)) =
	    VectorPair.foldr (fn (pat, exp, (cr, idsExpr)) =>
			      let
				  val (cs, idsExps) = derec' (pat, exp)
			      in
				  (cs @ cr, idsExps @ idsExpr)
			      end) (nil, nil) (pats, exps)
	  | derec' (TupPat (_, pats), ProdExp (_, expFields)) =
	    (case FieldSort.sort (Vector.toList expFields) of
		 (expFields', FieldSort.Tup _) =>
		     VectorPair.foldr
		     (fn (pat, Field (_, _, exp), (cr, idsExpr)) =>
		      let
			  val (cs, idsExps) = derec' (pat, exp)
		      in
			  (cs @ cr, idsExps @ idsExpr)
		      end) (nil, nil) (pats, expFields')
	       | (_, FieldSort.Prod) =>
		     raise Crash.Crash
			 "SimplifyRec.derec' 1 type inconsistency")
	  | derec' (ProdPat (_, _), TupExp (_, _)) =
	    raise Crash.Crash "SimplifyRec.derec' 2 type inconsistency"
	  | derec' (ProdPat (_, patFields), ProdExp (_, expFields)) =
	    let
		val (expFields', _) = FieldSort.sort (Vector.toList expFields)
	    in
		VectorPair.foldr
		(fn (Field (_, _, pat), Field (_, _, exp), (cr, idsExpr)) =>
		 let
		     val (cs, idsExps) = derec' (pat, exp)
		 in
		     (cs @ cr, idsExpr @ idsExpr)
		 end) (nil, nil) (patFields, expFields')
	    end
	  | derec' (VecPat (_, pats), VecExp (_, exps)) =
	    VectorPair.foldr (fn (pat, exp, (cr, idsExpr)) =>
			      let
				  val (cs, idsExps) = derec' (pat, exp)
			      in
				  (cs @ cr, idsExps @ idsExpr)
			      end) (nil, nil) (pats, exps)
	  | derec' (pat as AsPat (_, _, _), exp) =
	    let
		val (ids, patOpt) = unalias pat
	    in
		case patOpt of
		    NONE =>
			(nil, [(ids, exp)])
		  | SOME pat' =>
			let
			    val (pat'', exp') = patToExp pat'
			    val (constraints, idsExpList) = derec' (pat'', exp)
			in
			    (constraints, (ids, exp')::idsExpList)
			end
	    end
	  | derec' (pat, _) =
	    raise Crash.Crash "SimplifyRec.derec' 3 internal error"

	fun unify (JokPat _, pat2) = (nil, pat2)
	  | unify (pat1, JokPat _) = (nil, pat1)
	  | unify (pat1 as LitPat (info, lit1), LitPat (_, lit2)) =
	    if lit1 = lit2 then (nil, pat1)
	    else Error.error (#region info, "pattern never matches")
	  | unify (VarPat (info, id), pat2) = (nil, AsPat (info, id, pat2))
	  | unify (pat1, VarPat (info, id)) = (nil, AsPat (info, id, pat1))
	  | unify (TagPat (info, lab as Lab (_, label), pat1, isNAry),
		   TagPat (_, Lab (_, label'), pat2, _)) =
	    let
		val (constraints, pat) = unify (pat1, pat2)
	    in
		if label = label' then
		    (constraints, TagPat (info, lab, pat, isNAry))
		else Error.error (#region info, "pattern never matches")
	    end
	  | unify (ConPat (info, longid, pat1, isNAry),
		   ConPat (_, longid', pat2, _)) =
	    let
		val (constraints, pat) = unify (pat1, pat2)
	    in
		((longid, longid')::constraints,
		 ConPat (info, longid, pat, isNAry))
	    end
	  | unify (RefPat (info, pat1), RefPat (_, pat2)) =
	    let
		val (constraints, pat) = unify (pat1, pat2)
	    in
		(constraints, RefPat (info, pat))
	    end
	  | unify (TupPat (info, pats1), TupPat (_, pats2)) =
	    let
		val (constraints, pats) =
		    VectorPair.foldr (fn (pat1, pat2, (cr, patr)) =>
				      let
					  val (cs, pat) = unify (pat1, pat2)
				      in
					  (cs @ cr, pat::patr)
				      end) (nil, nil) (pats1, pats2)
	    in
		(constraints, TupPat (info, Vector.fromList pats))
	    end
	  | unify (ProdPat (info, patFields1), ProdPat (_, patFields2)) =
	    let
		val (constraints, patFields) =
		    VectorPair.foldr
		    (fn (Field (info, label, pat1),
			 Field (_, _, pat2), (cr, patFieldr)) =>
		     let
			 val (cs, pat) = unify (pat1, pat2)
		     in
			 (cs @ cr,
			  Field (info, label, pat)::patFieldr)
		     end) (nil, nil) (patFields1, patFields2)
	    in
		(constraints, ProdPat (info, Vector.fromList patFields))
	    end
	  | unify (VecPat (info, pats1), VecPat (_, pats2)) =
	    if Vector.length pats1 = Vector.length pats2 then
		let
		    val (constraints, pats) =
			VectorPair.foldr
			(fn (pat1, pat2, (cr, patr)) =>
			 let
			     val (cs, pat) = unify (pat1, pat2)
			 in
			     (cs @ cr, pat::patr)
			 end) (nil, nil) (pats1, pats2)
		in
		    (constraints, VecPat (info, Vector.fromList pats))
		end
	    else Error.error (#region info, "pattern never matches")
	  | unify (AsPat (info, id, pat1), pat2) =
	    let
		val (constraints, pat) = unify (pat1, pat2)
	    in
		(constraints, AsPat (info, id, pat))
	    end
	  | unify (pat1, pat2 as AsPat (_, _, _)) = unify (pat2, pat1)
	  | unify (pat, _) =
	    Error.error (#region (infoPat pat), "pattern never matches")

	fun parseRow row =
	    if Type.isEmptyRow row then
		if Type.isUnknownRow row then
		    raise Crash.Crash "SimplifyRec.parseRow type inconsistency"
		else nil
	    else Type.headRow row::parseRow (Type.tailRow row)

	fun getField (Field (_, _, pat)) = pat

	fun preprocess (I.JokPat info) = (nil, JokPat info)
	  | preprocess (I.LitPat (info, lit)) = (nil, LitPat (info, lit))
	  | preprocess (I.VarPat (info, id)) = (nil, VarPat (info, id))
	  | preprocess (I.TagPat (info, label, pat, isNAry)) =
	    let
		val (constraints, pat') = preprocess pat
	    in
		(constraints, TagPat (info, label, pat', isNAry))
	    end
	  | preprocess (I.ConPat (info, longid, pat, isNAry)) =
	    let
		val (constraints, pat') = preprocess pat
	    in
		(constraints, ConPat (info, longid, pat', isNAry))
	    end
	  | preprocess (I.RefPat (info, pat)) =
	    let
		val (constraints, pat') = preprocess pat
	    in
		(constraints, RefPat (info, pat'))
	    end
	  | preprocess (I.TupPat (info, pats)) =
	    let
		val (constraints, pats) =
		    Vector.foldr (fn (pat, (cr, patr)) =>
				  let
				      val (cs, pat) = preprocess pat
				  in
				      (cs @ cr, pat::patr)
				  end) (nil, nil) pats
	    in
		(constraints, TupPat (info, Vector.fromList pats))
	    end
	  | preprocess (I.ProdPat (info, patFields)) =
	    let
		val typ = #typ info
		val labelTypList =
		    if Type.isTuple' typ then
			Vector.foldri (fn (i, typ, rest) =>
				       (Label.fromInt (i + 1), typ)::rest)
			nil (Type.asTuple' typ, 0, NONE)
		    else parseRow (Type.asProd' typ)
		fun adjoin (labelTyp as (label, _), patFields as
			    (Field (_, Lab (_, label'), _)::rest)) =
		    if label = label' then patFields
		    else adjoin (labelTyp, rest)
		  | adjoin ((label, typ), nil) =
		    let
			val info = {region = Source.nowhere}
		    in
			[Field (info, Lab (info, label),
				I.JokPat {region = Source.nowhere, typ = typ})]
		    end
		val patFields' =
		    List.foldr adjoin (Vector.toList patFields) labelTypList
		val (patFields'', arity) = FieldSort.sort patFields'
		val (constraints, patFields''') =
		    Vector.foldr
		    (fn (Field (info, label, pat), (cr, fieldr)) =>
		     let
			 val (cs, pat') = preprocess pat
		     in
			 (cs @ cr,
			  Field (info, label, pat')::fieldr)
		     end) (nil, nil) patFields''
		val patFields'''' = Vector.fromList patFields'''
		val pat' =
		    case arity of
			FieldSort.Tup i =>
			    TupPat (info, Vector.map getField patFields'''')
		      | FieldSort.Prod =>
			    ProdPat (info, patFields'''')
	    in
		(constraints, pat')
	    end
	  | preprocess (I.VecPat (info, pats)) =
	    let
		val (constraints, pats) =
		    Vector.foldr (fn (pat, (cr, patr)) =>
				  let
				      val (cs, pat) = preprocess pat
				  in
				      (cs @ cr, pat::patr)
				  end) (nil, nil) pats
	    in
		(constraints, VecPat (info, Vector.fromList pats))
	    end
	  | preprocess (I.AsPat (_, pat1, pat2)) =
	    let
		val (constraints1, pat1') = preprocess pat1
		val (constraints2, pat2') = preprocess pat2
		val (constraints3, pat') = unify (pat1', pat2')
	    in
		(constraints1 @ constraints2 @ constraints3, pat')
	    end
	  | preprocess (I.AltPat (info, _)) =
	    Error.error (#region info,
			 "alternative pattern not allowed in val rec")
	  | preprocess (I.NegPat (info, _)) =
	    Error.error (#region info,
			 "negated pattern not allowed in val rec")
	  | preprocess (I.GuardPat (info, _, _)) =
	    Error.error (#region info,
			 "guard pattern not allowed in val rec")
	  | preprocess (I.WithPat (info, _, _)) =
	    Error.error (#region info,
			 "with pattern not allowed in val rec")

	fun derec (ValDec (_, pat, exp)::decr) =
	    let
		val (constraints, pat') = preprocess pat
		val (constraints', idsExpList) = derec' (pat', exp)
		val (idExpList, aliases) =
		    List.foldr (fn ((ids, exp), (rest, subst)) =>
				let
				    val toId = List.hd ids
				    val info = infoExp exp
				in
				    ((toId, exp)::rest,
				     List.foldr
				     (fn (fromId, subst) =>
				      (fromId, toId, info)::subst)
				     subst (List.tl ids))
				end) (nil, nil) idsExpList
		val (constraints'', idExpList', aliases') = derec decr
	    in
		(constraints @ constraints' @ constraints'',
		 idExpList @ idExpList', aliases @ aliases')
	    end
	  | derec (RecDec (_, decs)::decr) =
	    let
		val (constraints, idExpList, aliases) =
		    derec (Vector.toList decs)
		val (constraints', idExpList', aliases') = derec decr
	    in
		(constraints @ constraints',
		 idExpList @ idExpList', aliases @ aliases')
	    end
	  | derec nil = (nil, nil, nil)
    end
