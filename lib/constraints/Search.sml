(*
 * Authors:
 *   Thorsten Brunklaus <brunklaus@ps.uni-sb.de>
 *
 * Copyright:
 *   Thorsten Brunklaus, 2000
 *
 * Last Change:
 *   $Date$ by $Author$
 *   $Revision$
 *
 *)

import structure Space from "x-alice:/lib/constraints/Space.ozf"
import signature SEARCH from "x-alice:/lib/constraints/SEARCH.ozf"

structure Search :> SEARCH =
    struct
	open Space
	open List

	type 'a pruner = 'a * 'a -> unit
	    
	local
	    fun doSearchOne s =
		(case ask s of
		     FAILED          => NONE
		   | SUCCEEDED       => SOME(s)
		   | ALTERNATIVES(n) =>
			 let
			     val c = clone s
			 in
			     (commit(s, SINGLE(1));
			      (case doSearchOne s of
				   NONE => (commit(c, RANGE(2, n)); doSearchOne c)
				 | gs   => gs))
			 end)
	in
	    fun searchOne p =
		(case doSearchOne (space p) of
		     NONE    => NONE
		   | SOME(s) => SOME(merge s))
	end
    
	local
	    fun doSearchAll s =
		(case ask s of
		     FAILED          => nil
		   | SUCCEEDED       => [s]
		   | ALTERNATIVES(n) =>
			 let
			     val c = clone s
			 in
			     (commit(s, SINGLE(1));
			      commit(c, RANGE(2, n));
			      doSearchAll(s) @ doSearchAll(c))
			 end)
	in
	    fun searchAll p = map merge (doSearchAll (space p))
	end
    
	fun searchBest(p, ofun) =
	    let
		fun constrain(s, bs) =
		    let
			val or = merge (clone bs)
		    in
			inject(s, fn nr => ofun(or, nr))
		    end
		fun doSearchBest(s, bs) =
		    (case ask s of
			 FAILED          => bs
		       | SUCCEEDED       => s
		       | ALTERNATIVES(n) =>
			     let
				 val c = clone s
			     in
				 (commit(s, SINGLE(1));
				  commit(c, RANGE(2, n));
				  let
				      val nbs = doSearchBest(s, bs)
				  in
				      (case eq(bs, nbs) of
					   false => (constrain(c, nbs);
						     doSearchBest(c, nbs))
					 | true  => doSearchBest(c, nbs))
				  end)
			     end)
		val s  = space p
		val bs = doSearchBest(s, s)
	    in
		(case ask bs of
		     SUCCEEDED => SOME(merge bs)
		   | _         => NONE)
	    end
    end
