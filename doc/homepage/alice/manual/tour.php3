<?php include("macros.php3"); ?>
<?php heading("A Short Tour of Alice", "A Short Tour of Alice") ?>


<?php section("overview", "overview") ?>

<P>This page is meant as a short introduction to the Alice language and system
and its features:</P>

<UL>
  <LI><A href="#sml">Standard ML compatibility</A></LI>
  <LI><A href="#interactive">Interactive use</A>: evaluating declarations and
  browsing results</LI>
  <LI><A href="#laziness">Laziness</A>: transparent lazy evaluation on demand</LI>
  <LI><A href="#concurrency">Concurrency</A>: threads and data-flow
  synchronistation</LI>
  <LI><A href="#promises">Promises</A>: </LI>
  <LI><A href="#components">Components</A>: platform independence and
  lazy dynamic linking</LI>
  <LI><A href="#packages">Packages</A>: dynamic typing and first-class modules</LI>
  <LI><A href="#pickling">Pickling</A>: platform independent persistence</LI>
  <LI><A href="#distribution">Distribution</A>: </LI>
  <LI><A href="#constraints">Constraint Programming</A>: </LI>
  <LI><A href="#interop">Interoperability</A>: working hand in hand with Oz
  programs</LI>
</UL>


<?php section("sml", "standard ML") ?>

<P>Alice ML is an extension of the
<A href="http://cm.bell-labs.com/cm/cs/what/smlnj/sml.html">Standard ML</A> language (SML).
Most of the examples shown here assume a working knowledge of functional
programming in general and SML in particular. There are numerous
books and tutorials available for SML.</P>

<P>Online Material:</P>

<UL>
  <LI><A href="http://www-2.cs.cmu.edu/People/rwh/introsml/">Programming in
  Standard ML</A>, by Robert Harper, CMU</LI>
  <LI><A href="http://www.dcs.ed.ac.uk/home/stg/NOTES/">Programming in Standard
  ML '97: An Online Tutorial</A>, by Stephen Gilmore, University of
  Edinburgh</LI>
</UL>

<P>Paper Books:</P>

<UL>
  <LI><A href="http://www.cl.cam.ac.uk/users/lcp/MLbook/">ML for the Working
  Programmer</A> (2nd edition), by Larry Paulson. Cambridge University
  Press</LI>
  <LI><A href="http://www-db.stanford.edu/~ullman/emlp.html">Elements of ML
  Programming</A> (ML'97 edition), by Jeffrey Ullmann. Prentice-Hall</LI>
</UL>

<P>The definition of the language and its library can be found here:</P>

<UL>
  <LI><A href="http://mitpress.mit.edu/book-home.tcl?isbn=0-262-63181-4">The
  Definition of Standard ML</A> (Revised), by Robin Milner, Mads Tofte,
  Robert Harper, Dave MacQueen. The MIT Press</LI>
  <LI><A href="http://SML.sourceforge.net/Basis/">The Standard ML
  Basis Library</A> (Preliminary), by John Reppy and Emden Gansner.</LI>
</UL>

<P>For a more comprehensive literature list, see the
<A href="http://www.smlnj.org/doc/literature.html#tutorials">bibliography</A>
on the SML/NJ site.</P>


<?php section("interactive", "interactive toplevel") ?>

<P>Alice ML is an extension of Standard ML, and the Alice
<A href="usage.php3#interactive">interactive toplevel</A>
functions very similar to the interactive prompts known from other SML
systems where you can type in expressions and declarations to evaluate them.
Input is terminated with a semicolon. For example, you might simply perform a
simple calculation:</P>

<PRE>
- 4+5;
<I>val it : int = 9</I></PRE>

<P>The expression is evaluated and the result <TT>9</TT> printed along with
its inferred type <TT>int</TT>. Anonymous expressions get the name <TT>it</TT>,
so that you can refer to them in consecutive inputs:</P>

<PRE>
- 2*it;
<I>val it : int = 18</I></PRE>

<P>We can also try the one-line Hello World program:</P>

<PRE>
- print "Hello world!\n";
<I>Hello world!
val it : unit = ()</I></PRE>

<P>Entering a function declaration is more interesting. For example,
the factority function:<P>

<PRE>
- fun fac 0 = 1
    | fac n = n * fac (n-1);
<I>val fac : int -> int = fn</I></PRE>

<P>This time, the result has a more complex type: it is a function from
integers to integers. We can apply that function:</P>

<PRE>
- fac 50;
<I>val it : int = 30414093201713378043612608166064768844377641568960512000000000000</I></PRE>

<P>For more complex values, the static output of the result is often
insufficient. The Alice system includes the <EM>Inspector</EM> for browsing
arbitrary data structures interactively:</P>

<PRE>
- inspect (List.tabulate (100, fn i => (i, i*i, i*i*i)));
<I>val it : unit = ()</I></PRE>

<P>An inspector window will pop up displaying the table of the first hundred
square and cubic numbers.</P>

inspect ({hello = "hello, world"}, 3 + 8);

val rec infiniteList = 1::infiniteList;
inspect infiniteList;

inspect (Future.alarm (Time.fromMilliseconds 2000));


<?php section("laziness", "laziness") ?>

open Future

fun fib () =
    let
	fun gen (a, b) = byneed (fn () => a::gen (b, a + b))
    in
	gen (1, 1)
    end

val fibs = fib ()

Inspector.inspect fibs;

val _ = List.take (fibs, 5)

val f: int = byneed (fn () =>
			(TextIO.print "hello, world\n";
			 raise Match));

inspect f;

Future.await f handle e => (Inspector.inspect e; 1);


val hole: int = Hole.hole ()

Inspector.inspect hole;

val future = Hole.future hole

Inspector.inspect future;

Hole.fill (hole, 17);


<?php section("concurrency", "concurrency") ?>

fun fib (0 | 1) = 1
  | fib n       = fib (n-1) + fib (n-2);

spawn fib 30;

inspect (List.tabulate (30, fn i => spawn fib i));


<?php section("promises", "promises") ?>


(* Promises and Futures *)

open Promise

signature PORT =
sig
    type 'a port

    val new: unit -> 'a port * 'a list
    val send: 'a port * 'a -> unit
    val close: 'a port -> unit
end

structure Port :> PORT =
struct
    type 'a port = 'a list promise ref

    fun new () =
	let
	    val p = promise()
	in
	    (ref p, future p)
	end

    fun send (r, x) =
	let
	    val p' = promise()
	    val p = Ref.exchange (r, p')
	in
	    fulfill(p, x::future p')
	end

    fun close r = fulfill(!r, nil)
end

val (p: int Port.port, xs) = Port.new ()

Inspector.inspect xs;

Port.send (p, 17);

Port.send (p, 7);


inspect (Future.concur (fn () => Future.alarm (Time.fromMilliseconds 6000)));


<?php section("components", "components") ?>

(* alicec -c MY_COMPONENT-sig.aml *)
(* alicec -c MyComponent.aml *)

import "/home/kornstae/stockhausen/doc/samples/MyComponent"

import structure MyComponent
from "/home/kornstae/stockhausen/doc/samples/MyComponent"

Inspector.inspect (MyComponent.fak 7);


<?php section("packages", "packages") ?>

(*
 * Packing and unpacking of a simple value.
 *)

structure PackVal   = Package.PackVal
structure UnpackVal = Package.UnpackVal

val  value = { a = 0,     b = "hello",   c = [4, 0, 2, 42] }
type ty    = { a : int,   b : string,    c : int list      }

structure P = PackVal(val x = value type t = ty)

Inspector.inspect P.package;

structure X = UnpackVal(val package = P.package type t = ty)
val value' = X.x

Inspector.inspect value';

structure X = UnpackVal(val package = P.package type t = int)
val value' = X.x


(*
 * Packing and unpacking of a polymorphic function (via modules).
 * Type can be more specific at unpacking.
 *)

structure P          = Package.Pack(structure X = (val f = length)
				    signature S = (val f : 'a list -> int))

structure Length     = Package.Unpack(val package = P.package
				      signature S = (val f: 'a list -> int))
structure IntLength  = Package.Unpack(val package = P.package
				       signature S = (val f: int list -> int))
structure RealLength = Package.Unpack(val package = P.package
				      signature S = (val f: real list -> int))

structure _ =
    Package.Unpack(val package = P.package
		   signature S = (val f: real option -> int))   (* Mismatch *)

val _ = print("length [1,2,1] = " ^ Int.toString(Length.f [1,2,1]) ^ "\n")
val _ = print("length [3,0] = " ^ Int.toString(IntLength.f [3,0]) ^ "\n")

val _ = print("length [1,2,1] = " ^ Int.toString(RealLength.f [1,2,1]) ^ "\n")

(*
 * Packing a datatype.
 *)

signature I =
sig
    datatype t = A | B of int
    val x: t
end

structure Y =
struct
    datatype t = A | B of int
    val x = B 5
end

structure P = Package.Pack(structure X = Y
			   signature S = I)

datatype t = A | B of int

structure Z = Package.Unpack(val package = P.package
			     signature S = sig val x: t end)

Inspector.inspect Z.x;


<?php section("pickling", "pickling") ?>

(*
 * Pickling and unpickling of an abstract type.
 * The unpickled type is compatible with the original one.
 *)

signature NUM =
    sig
	type t
	fun fromInt : int -> t
	fun toInt : t -> int
	fun add : t * t -> t
    end

structure Num :> NUM =
    struct
	type t = int
	fun toInt n   = n
	fun fromInt n = n
	val add       = op+
    end

val file = "Num." ^ Pickle.extension
structure  _ = Pickle.Save(val file = file
			   structure X = Num
			   signature S = NUM where type t = Num.t)

structure Num' = Pickle.Load(val file = file
			     signature S = NUM where type t = Num.t)
structure Num'' = Pickle.Load(val file = file
			      signature S = NUM)

Num'.add(Num'.fromInt 1, Num.fromInt 2);

Num''.add(Num''.fromInt 1, Num.fromInt 2); (* error *)

(*
 * Pickling of functors.
 *)

val file = "Hello." ^ Pickle.extension

functor MkHello(val who : string) =
    struct
	val s = "Hello " ^ who ^ "!\n"
    end

signature MK_HELLO = fct(val who : string) -> sig val s : string end

structure _        = Pickle.Save(val file = file
				 structure X = MkHello
				 signature S = MK_HELLO)
structure MkHello' = Pickle.Load(val file = file signature S = MK_HELLO)

structure Hello    = MkHello'(val who = "World")
val       _        = print(Hello.s)


(*
 * Pickling of signatures.
 * Signatures are first-class and can be pickled.
 * We can load pickles with statically unknown signatures.
 *)

val sigfile = "Sig." ^ Pickle.extension
val modfile = "Mod." ^ Pickle.extension

signature T      = fct(_ : any) -> sig    type t       end
structure X :> T = fct(_ : any) => struct type t = int end

structure  _  = Pickle.Save(val file = modfile
structure X = X signature S = T)

structure  _  = Pickle.Save(val file = sigfile
			    structure X = (signature U = T)
			    signature S = (signature U))
structure Sig = Pickle.Load(val file = sigfile
			    signature S = (signature U))
structure Mod = Pickle.Load(val file = modfile
			    signature S = Sig.U)

(*
 * Components are pickles and vice versa!
 *
 * Loading a component as a pickle will execute it and return the
 * component's content as a structure.
 * A structure pickle can be used as a component. It is a special case of
 * a component because its content is completely evaluated.
 * Note that unpickling an evaluated component produces new abstract
 * types! (so Url'.Url.t below is incompatible to the lib's Url.t)
 *)

val file = "Url." ^ Pickle.extension
val comp = "x-alice:/lib/system/" ^ file

import signature URL from "x-alice:/lib/system/URL-sig"

structure Url' = Pickle.Load(val file = comp
			     signature S = (structure Url : URL))

val _ = print(Url'.Url.toString(Url'.Url.fromString comp) ^ "\n")

structure _ = Pickle.Save(val file = file
			  structure X = Url'
			  signature S = (structure Url : URL))

import "/home/kornstae/stockhausen/doc/samples/Url"


<?php section("distribution", "distribution") ?>


<?php section("constraints", "constraints") ?>

import structure FD       from "x-alice:/lib/constraints/FD"

val x = FD.range (1, 5)
val y = FD.range (1, 5)

Inspector.inspect (x, y);

FD.less (x, y);

FD.notequal (x, FD.fromInt 3);

FD.equal (x, FD.fromInt 4);



import structure Search   from "x-alice:/lib/constraints/Search";
import structure Explorer from "x-alice:/lib/constraints/Explorer";

(*
 * Send + More = Money
 *)

fun money() =
    let
	val digits as #[S, E, N, D, M, O, R, Y] = FD.rangeVec(8, (0,9))
	val send                                = FD.fd NONE
	val more                                = FD.fd NONE
	val money                               = FD.fd NONE
	val zero                                = FD.fromInt 0
    in
	FD.sumC(#[(1000, S), (100, E), (10, N), (1, D)],
		FD.EQUAL, send);
	FD.sumC(#[(1000, M), (100, O), (10, R), (1, E)],
		FD.EQUAL, more);
	FD.sumC(#[(10000, M), (1000, O), (100, N), (10, E), (1, Y)],
		FD.EQUAL, money);
	FD.notequal(S, zero);
	FD.notequal(M, zero);
	FD.distinct(digits);
	FD.plus(send, more, money);
	FD.distribute(FD.FIRSTFAIL, digits);
	{S, E, N, D, M, O, R, Y}
    end

val _ = Explorer.exploreAll money

(*
 * Aligning for a Photo
 *)

structure Photo =
    struct
	datatype person = ALICE | BERT | CHRIS | DEB | EVAN

	val nPersons = 5

	fun personIndex ALICE = 0
	  | personIndex BERT  = 1
	  | personIndex CHRIS = 2
	  | personIndex DEB   = 3
	  | personIndex EVAN  = 4

	val prefs = #[(ALICE, CHRIS),
		      (BERT, EVAN),
		      (CHRIS, DEB),
		      (CHRIS, EVAN),
		      (DEB, ALICE),
		      (DEB, EVAN),
		      (EVAN, BERT)]

	fun photo() =
	    let
		val pos as #[alice, bert, chris, deb, evan]
			= FD.rangeVec(nPersons, (1, nPersons))
		val sat = FD.range(0, Vector.length prefs)
		val ful = Vector.map
		    (fn (a, b) =>
		     let
			 val c1     = FD.bin()
			 val c2     = FD.bin()
			 val result = FD.bin()
			 val zero   = FD.fromInt 0
			 val one    = FD.fromInt 1
			 val posA   = Vector.sub(pos, personIndex a)
			 val posB   = Vector.sub(pos, personIndex b)
		     in
			 FD.Reified.sumC(#[(1, one), (1, posA), (~1, posB)],
					 FD.EQUAL, zero, c1);
			 FD.Reified.sumC(#[(1, posA), (~1, posB)],
					 FD.EQUAL, one, c2);
			 FD.Reified.sum(#[c1, c2],
					FD.EQUAL, one, result);
			 result
		     end) prefs
	    in
		FD.distinct pos;
		FD.sum(ful, FD.EQUAL, sat);
		FD.distribute(FD.NAIVE, pos);
		({alice, bert, chris, deb, evan}, ful, sat)
	    end

	fun pruner((_, _, a), (_, _, b)) = FD.lessEq(a, b)
    end

(* Explore the Solution(s) *)
val _ = Explorer.exploreBest(Photo.photo, Photo.pruner)


<?php section("interop", "interoperability") ?>


<?php footing() ?>
