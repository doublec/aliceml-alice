(*
Invariants of type annotations:
- exp and pat nodes carry their instantiated type.
- id and longid nodes carry their generalized type.
  Ie. for every (long)id embedded into an exp or pat
  node the type annotating the id must be more general than the
  type annotating the exp/pat (exp and pat types may still be
  quantified).
*)

structure IntermediateInfo =
  struct
    type lab_info	= { region: Source.region }
    type id_info	= { region: Source.region, typ: Type.t }
    type longid_info	= { region: Source.region, typ: Type.t }
    type exp_info	= { region: Source.region, typ: Type.t }
    type pat_info	= { region: Source.region, typ: Type.t }
    type 'a field_info	= { region: Source.region }
    type match_info	= { region: Source.region }
    type dec_info	= { region: Source.region }
  end

structure IntermediateGrammar = MakeIntermediateGrammar(
	open IntermediateInfo
	type sign = Inf.sign)

structure PPIntermediateGrammar = MakePPIntermediateGrammar(
	structure IntermediateGrammar = IntermediateGrammar
	fun ppInfo _	= PrettyPrint.empty
	val ppLabInfo	= ppInfo
	val ppIdInfo	= ppInfo
	val ppLongidInfo = ppInfo
	val ppExpInfo	= ppInfo
	val ppPatInfo	= ppInfo
	val ppFieldInfo	= fn _ => ppInfo
	val ppMatchInfo	= ppInfo
	val ppDecInfo	= ppInfo
	val ppSig	= ppInfo)
