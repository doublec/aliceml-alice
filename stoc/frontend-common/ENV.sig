signature ENV =
  sig

    type stamp = AbstractGrammar.stamp
    type id    = AbstractGrammar.id
    type path  = Path.t
    type typ   = Type.t
    type var   = Type.var
    type inf   = Inf.t

    type env
    type t = env

    type val_entry = { id: id, path: path, typ: typ, sort: Inf.val_sort }
    type typ_entry = { id: id, path: path, typ: typ, sort: Inf.typ_sort }
    type var_entry = { id: id, var: var }
    type mod_entry = { id: id, path: path, inf: inf }
    type inf_entry = { id: id, path: path, inf: inf }

    exception Collision of stamp
    exception Lookup    of stamp

    val new :		unit -> env
    val copy :		env -> env
    val copyScope :	env -> env
    val splitScope :	env -> env
    val insertScope :	env -> unit
    val deleteScope :	env -> unit
    val mergeScope :	env -> unit

    val union :		env * env -> unit		(* Collision *)

    val insertVal :	env * stamp * val_entry -> unit	(* Collision *)
    val insertTyp :	env * stamp * typ_entry -> unit	(* Collision *)
    val insertVar :	env * stamp * var_entry -> unit	(* Collision *)
    val insertMod :	env * stamp * mod_entry -> unit	(* Collision *)
    val insertInf :	env * stamp * inf_entry -> unit	(* Collision *)

    val lookupVal :	env * stamp -> val_entry	(* Lookup *)
    val lookupTyp :	env * stamp -> typ_entry	(* Lookup *)
    val lookupVar :	env * stamp -> var_entry	(* Lookup *)
    val lookupMod :	env * stamp -> mod_entry	(* Lookup *)
    val lookupInf :	env * stamp -> inf_entry	(* Lookup *)

    val appVals :	(stamp * val_entry -> unit) -> env -> unit
    val appTyps :	(stamp * typ_entry -> unit) -> env -> unit
    val appVars :	(stamp * var_entry -> unit) -> env -> unit
    val appMods :	(stamp * mod_entry -> unit) -> env -> unit
    val appInfs :	(stamp * inf_entry -> unit) -> env -> unit

    val foldVals :	(stamp * val_entry * 'a -> 'a) -> 'a -> env -> 'a
    val foldTyps :	(stamp * typ_entry * 'a -> 'a) -> 'a -> env -> 'a
    val foldVars :	(stamp * var_entry * 'a -> 'a) -> 'a -> env -> 'a
    val foldMods :	(stamp * mod_entry * 'a -> 'a) -> 'a -> env -> 'a
    val foldInfs :	(stamp * inf_entry * 'a -> 'a) -> 'a -> env -> 'a

  end
