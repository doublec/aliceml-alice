signature PHASE =
  sig
    structure C: CONTEXT
    structure I: REPRESENTATION
    structure O: REPRESENTATION

    val translate: C.t -> Source.desc * I.t -> O.t   (* [Error.Error] *)
  end
