(*
 * Authors:
 *   Thorsten Brunklaus <brunklaus@ps.uni-sb.de>
 *   Andreas Rossberg <rossberg@ps.uni-sb.de>
 *
 * Copyright:
 *   Thorsten Brunklaus, 2000
 *
 * Last Change:
 *   $Date$ by $Author$
 *   $Revision$
 *
 *)

signature FD_COMPONENT =
    sig
	signature FD =
	    sig
		type fd
		type bin = fd

		datatype domain_element =
		    SINGLE of int
		  | RANGE  of int * int

		type domain = domain_element vector

		datatype relation =
		    LESS
		  | LESSEQ
		  | EQUAL
		  | NOTEQUAL
		  | GREATER
		  | GREATEREQ

		(* Allocation Functions *)
		val fd : domain option -> fd
		val fdVec : int * domain -> fd vector
		val range : int * int -> fd
		val rangeVec : int * (int * int) -> fd vector
		val bin : unit -> bin
		val binVec : int -> bin

		(* Conversion *)
		val toInt : fd -> int
		val fromInt : int -> fd
		val isBin : fd -> bool

		(* Standards Sums *)
		val sum : fd vector * relation * fd -> unit
		val sumC : (int * fd) vector * relation * fd -> unit
		val sumAC : (int * fd) vector * relation * fd -> unit
		val sumCN : (int * fd vector) vector * relation * fd -> unit
		val sumACN : (int * fd vector) vector * relation * fd -> unit
		val sumD : fd vector * relation * fd -> unit
		val sumCD : (int * fd) vector * relation * fd -> unit

		(* Standard Propagators; Interval propagation *)
		val plus : fd * fd * fd -> unit (* X + Y =: Z *)
		val minus : fd * fd * fd -> unit (* X - Y =: Z *)
		val times : fd * fd * fd -> unit (* X * Y =: Z *)
		val power : fd * int * fd -> unit (* pow(X, I) =: Z *)
		val divI : fd * int * fd -> unit (* X divI I =: Z *)
		val modI : fd * int * fd -> unit (* X modI I =: Z *)

		(* Standard Propagators; Domain propagation *)
		val plusD : fd * fd * fd -> unit (* X + Y =: Z *)
		val minusD : fd * fd * fd -> unit (* X - Y =: Z *)
		val timesD : fd * fd * fd -> unit (* X * Y =: Z *)
		val divD : fd * int * fd -> unit (* X divD I =: Z *)
		val modD : fd * int * fd -> unit (* X modD I =: Z *)
		    
		val min : fd * fd * fd -> unit (* min(X, Y) =: Z *)
		val max : fd * fd * fd -> unit (* max(X, Y) =: Z *)
		    
		val equal : fd * fd -> unit (* X =: Y *)
		val notequal : fd * fd -> unit (* X \=: Y *)
		val distance : fd * fd * relation * fd -> unit
		val less : fd * fd -> unit (* X <: Y *)
		val lessEq : fd * fd -> unit (* X <=: Y *)
		val greater : fd * fd -> unit (* X >: Y *)
		val greaterEq : fd * fd -> unit (* X >=: Y *)
		val disjoint : fd * int * fd * int -> unit
		val disjointC : fd * int * fd * int * bin -> unit
		val tasksOverlap : fd * int * fd * int * bin -> unit

		(* Non-Linear Propagators *)
		val distinct : fd vector -> unit
		val distinctOffset : (fd * int) vector -> unit
		val distinct2 : ((fd * int) * (fd * int)) vector -> unit
		val atMost : fd * fd vector * int -> unit
		val atLeast : fd * fd vector * int -> unit
		val exactly : fd * fd vector * int -> unit
		val element : fd * int vector * fd -> unit

		(* 0/1 Propagators *)
		val conj : bin * bin * bin -> unit
		val disj : bin * bin * bin -> unit
		val exor : bin * bin * bin -> unit
		val nega : bin * bin -> unit
		val impl : bin * bin * bin -> unit
		val equi : bin * bin * bin -> unit
		    
		(* Reified Constraints *)
		structure Reified :
		    sig
			(* Reified Variable is returned *)
			val fd : domain * bin -> fd
			(* Reified Vector of Variables is returned *)
			val fdVec : int * domain * bin -> fd vector
			(* Same as in Oz *)
			val card : int * bin vector * int * bin -> unit
			val distance : fd * fd * relation * fd * bin -> unit
			val sum : fd vector * relation * fd * bin -> unit
			val sumC : (int * fd) vector * relation * fd * bin -> unit
			val sumAC : (int * fd) vector * relation * fd * bin -> unit
			val sumCN : (int * fd vector) vector * relation * fd * bin -> unit
			val sumACN : (int * fd vector) vector * relation * fd * bin -> unit
		    end

		(* Reflection *)
		structure Reflect :
		    sig
			val min : fd -> int
			val max : fd -> int
			val mid : fd -> int
			val nextLarger : fd * int -> int
			val nextSmaller : fd * int -> int
			val size : fd -> int
			val dom : fd -> domain
			val domList : fd -> int list
			val nbSusps : fd -> int
		    end

		(* Watching (obsolete?) *)
		structure Watch :
		    sig
			val min : fd * int -> bool
			val max : fd * int -> bool
			val size : fd * int -> bool
		    end

		(* Distribution *)
		datatype dist_mode =
		    NAIVE
		  | FIRSTFAIL
		  | SPLIT

		val distribute : dist_mode * fd vector -> unit
	    end

	structure FD : FD
    end
