structure PPInf :> PP_INF =
  struct

    (* Import *)

    open InfPrivate
    open PrettyPrint
    open PPMisc

    infixr ^^ ^/^


    (* Helpers *)

    fun uncurry(ref(APPLY(j1,p,_))) = let val (j,ps) = uncurry j1
				      in (j,ps@[p]) end
      | uncurry j		    = (j,[])


    (* Simple objects *)

    fun ppLab l		= text(Label.toString l)
    fun ppCon (k,p)	= PPPath.ppPath p


    (* Interfaces *)

    (* Precedence:
     *	0 : binders (LAMBDA(id : inf1) . inf2)
     *	1 : constructed type (inf(path))
     *)

    fun ppInf(ref j') = fbox(below(ppInf' j'))

    and ppInf'(TOP) =
	    text "TOP"

      | ppInf'(CON c) =
	    ppCon c

      | ppInf'(SIG s) =
	    ppSig' s

      | ppInf'(FUN(p,j1,j2)) =
	let
	    val doc = ppBinder("FCT",p,j1,j2)
	in
	    fbox(below doc)
	end

      | ppInf'(LAMBDA(p,j1,j2)) =
	let
	    val doc = ppBinder("LAMBDA",p,j1,j2)
	in
	    fbox(below doc)
	end

      | ppInf'(j' as APPLY _) =
	let
	    val (j,ps) = uncurry(ref j')
	in
	    fbox(nest(List.foldl (fn(p,d) => d ^/^ paren(PPPath.ppPath p))
				 (ppInf j) ps))
	end

      | ppInf'(ABBREV(j1,j2)) =
	    ppInf j1

      | ppInf'(LINK j) =
(*DEBUG
text "@" ^^*)
	    ppInf j

    and ppBinder(s,p,j1,j2) =
	    abox(
		fbox(
		    text s ^^
		    text "(" ^/^
		    below(break ^^
			PPPath.ppPath p ^/^
			text ":" ^^
			nest(break ^^
			    ppInf j1
			)
		    ) ^/^
		    text ")" ^/^
		    text "."
		) ^^
		nest(break ^^
		    ppInf j2
		)
	    )


    (* Signatures *)

    and ppSig' s =
	let
	    val doc = ppSig s
	in
	    abox(below(
		text "sig" ^^
		(if isEmpty doc then
		    empty
		 else
		    nest(vbox(break ^^ doc))
		) ^^ break ^^
		text "end"
	    ))
	end

    and ppSig(ref items, _) = vbox(List.foldl ppItem empty items)

    and ppItem(ref item', doc) = ppItem'(item', doc)

    and ppItem'(VAL((p,l,0), t, d), doc) =
	if String.sub(Label.toString l,0) = #"'" then
	    doc
	else
	    abox(
		hbox(
		    text "val" ^/^ ppLab l ^/^ text ":"
(*DEBUG
		    (if String.sub(Label.toString l,0) <> #"'" then
			 text "val" ^/^ ppLab l
		     else
			 text "constructor" ^/^
			 text(String.extract(Label.toString l, 1, NONE))
		    ) ^/^
(*DEBUG
text "(" ^^ PPPath.ppPath p ^^ text ")" ^/^*)
		    text ":"
*)
		) ^^
		nest(break ^^
		    abox(PPType.ppTyp t)
		) ^^
		(case d of NONE => empty | SOME p' =>
		if Path.equals(p',p) then empty else
		nest(break ^^
		    abox(text "=" ^/^ PPPath.ppPath p')
		))
	    ) ^/^ doc

      | ppItem'(TYP((p,l,0), k, d), doc) =
	if Option.isNone d
	orelse let val t = Option.valOf d
	       in Type.isCon t andalso Path.equals(#3(Type.asCon t), p) end then
	    abox(
		hbox(
		    text "type" ^/^
		    ppLab l ^/^
(*DEBUG
text "(" ^^ PPPath.ppPath p ^^ text ")" ^/^*)
		    text ":"
		) ^^
		nest(break ^^
		    abox(PPType.ppKind k)
		)
	    ) ^/^ doc
	else
	    abox(
		hbox(
		    text "type" ^/^
		    ppLab l ^/^
		    text "="
		) ^^
		nest(break ^^
		    abox(PPType.ppTyp(Option.valOf d))
		)
	    ) ^/^ doc

      | ppItem'(MOD((p,l,0), j, d), doc) =
	    abox(
		hbox(
		    text(if isArrow j then "functor" else "structure") ^/^
		    ppLab l ^/^
(*DEBUG
text "(" ^^ PPPath.ppPath p ^^ text ")" ^/^*)
		    text ":"
		) ^^
		nest(break ^^
		    abox(ppInf j) ^^
		    (case d of NONE => empty | SOME p' =>
		     if Path.equals(p',p) then empty else
		     nest(break ^^
			 hbox(text "=" ^/^ hbox(PPPath.ppPath p'))
		    ))
		)
	    ) ^/^ doc

      | ppItem'(INF((p,l,0), k, d), doc) =
	if Option.isNone d
	orelse let val j = Option.valOf d
	       in isCon j andalso Path.equals(#2(asCon j), p) end then
	    abox(
		hbox(
		    text "signature" ^/^
		    ppLab l ^/^
(*DEBUG
text "(" ^^ PPPath.ppPath p ^^ text ")" ^/^*)
		    text ":"
		) ^^
		nest(break ^^
		    abox(ppKind k)
		)
	    ) ^/^ doc
	else
	    abox(
		hbox(
		    text "signature" ^/^
		    ppLab l ^/^
(*DEBUG
text "(" ^^ PPPath.ppPath p ^^ text ")" ^/^*)
		    text "="
		) ^^
		nest(break ^^
		    abox(ppInf(Option.valOf d))
		)
	    ) ^/^ doc

      | ppItem'(FIX((p,l,0), f), doc) =
	    hbox(
		let open Fixity in
		    (case f
		      of NONFIX    => text "nonfix"
		       | PREFIX n  => text "prefix" ^/^ text(Int.toString n)
		       | POSTFIX n => text "postfix" ^/^ text(Int.toString n)
		       | INFIX(n,LEFT) => text "infix" ^/^ text(Int.toString n)
		       | INFIX(n,RIGHT) =>
				text "infixr" ^/^ text(Int.toString n)
		       | INFIX(n,NEITHER) =>
				text "infixn" ^/^ text(Int.toString n)
		    ) ^/^
		    ppLab l
		end
	    ) ^/^ doc

      | ppItem'(_, doc) = doc		(* hidden item *)


    (* Kinds *)

    and ppKind(ref k') = fbox(below(ppKind' k'))

    and ppKind'(GROUND) =
	    text "*"

      | ppKind'(DEP(p,j,k)) =
	    fbox(below(
		abox(
		    fbox(
			text "PI" ^/^
			text "(" ^^
			below(break ^^
			    PPPath.ppPath p ^/^
			    text ":" ^^
			    nest(break ^^
				ppInf j
			    )
			) ^/^
			text ")" ^/^
			text "."
		    ) ^^
		    nest(break ^^
			ppKind k
		    )
		)
	    ))

  end
