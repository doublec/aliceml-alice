(* very simple (toplevel) grammar definition *)
signature MYTOKEN =
sig
    token  PLUS | MINUS | TIMES | NUM of int
end

structure a =
struct
    token PLUS | MINUS | TIMES | NUM of int 

    assocl TIMES
    assocl PLUS MINUS


    rule exp : int = 
        NUM 
      | n1 as exp, oper1, n2 as exp => (oper1(n1,n2)) prec PLUS
      | n1 as exp, oper2, n2 as exp => (oper2(n1,n2)) prec TIMES
    and oper1 =
        PLUS  => (op+)
      | MINUS => (op-)
    and oper2 =
	TIMES => (op*)

    parser eval = exp
    parser eval2 = exp
    
    val lexer = 
	let val t = [NUM 5, MINUS, NUM 3]
	    fun f x = (SOME x,1,1)
	    val t = ref (map f t)
	in fn () =>
	    let val h = hd (!t) in (t:=tl(!t); h)  end handle _ => (NONE,1,1)
	end
end
