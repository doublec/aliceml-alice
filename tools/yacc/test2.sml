(* very simple (toplevel) grammar definition *)
structure arithmetic =
struct

    token PLUS | MINUS | TIMES | NUM of int

    assocl TIMES
    assocl PLUS MINUS


    rule exp : int = 
        NUM 
      | n1 as exp, oper, n2 as exp => (oper(n1,n2))
    and oper =
        PLUS  => (op+)
      | MINUS => (op-)
      | TIMES => (op*)

    parser eval = exp
        parser eval2 = oper(* *)
    
    val lexer = 
	let val t = [NUM 5, PLUS, NUM 3, TIMES, NUM (~2), EOP]
	    fun f x = (x,1,1)
	    val t = ref (map f t)
	in fn () =>
	    let val h = hd (!t) in (t:=tl(!t); h)  end handle _ => (EOP,1,1)
	end
end
