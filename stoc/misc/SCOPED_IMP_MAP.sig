(*
 * A stateful scoped symbol table (a stack of hashtables).
 *)

signature SYMTABLE =
  sig

    type key
    type 'a symtable
    type 'a t = 'a symtable

    exception Lookup
    exception Collision of key

    val new :		unit -> 'a symtable
    val copy :		'a symtable -> 'a symtable
    val copyScope:	'a symtable -> 'a symtable

    val insertScope :	'a symtable -> unit
    val deleteScope :	'a symtable -> unit
    val delete2ndScope:	'a symtable -> unit
    val mergeScope :	'a symtable -> unit

    val insert :	'a symtable * key * 'a -> unit
    val insertDisjoint:	'a symtable * key * 'a -> unit		(* Collision *)
    val plus :		'a symtable * 'a symtable -> unit
    val plusDisjoint :	'a symtable * 'a symtable -> unit	(* Collision *)

    val lookup :	'a symtable * key -> 'a			(* Lookup *)
    val lookupScope :	'a symtable * key -> 'a			(* Lookup *)

    val app :		(key * 'a -> unit) -> 'a symtable -> unit
    val fold :		((key * 'a) * 'b -> 'b) -> 'b -> 'a symtable -> 'b

  end
