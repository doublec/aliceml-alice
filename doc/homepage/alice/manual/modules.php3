<?php include("macros.php3"); ?>

<?php heading("Extensions to the Module Language",
		"module <BR> language <BR> extensions") ?>


<?php section("overview", "overview") ?>

<P>Alice ML extends the SML module system in various ways, by providing:</P>

<UL>
  <LI> <A href="#local">Local modules</A> </LI>
  <LI> <A href="#higher">Higher-order functors</A> </LI>
  <LI> <A href="#sigmembers">Signature members and abstract signatures</A> </LI>
<!--
  <LI> <A href="3#paramsig">Parameterized signatures</A> </LI>
  <LI> <A href="#singleton">Singleton signatures</A> </LI>
-->
  <LI> <A href="#lazy">Lazy evaluation</A> </LI>
  <LI> <A href="#fixity">Fixity specifications</A> </LI>
  <LI> <A href="#sugar">Syntax enhancements</A> </LI>
</UL>

<P>A <A href="#syntax">syntax summary</A> is given below.</P>



<?php section("local", "local modules") ?>

<P>Alice discards SML's stratification of the core and module language. Core
declarations (<I>dec</I>), structure declarations (<I>strdec</I>), and toplevel
declarations (<I>topdec</I>) are collapsed into one class. As a consequence,
structures can be declared local to an expression (via <TT>let</TT>) and
functors as well as signatures can be nested into structures. For example: </P>

<PRE class=code>
fun sortIntList ns =
    let
        structure Tree = MkBinTree (type t = int)
    in
	Tree.toList (foldl Tree.insert Tree.empty ns)
    end</PRE>



<?php section("higher", "higher-order functors") ?>

<?php subsection("higher-strexp", "Functor expressions") ?>

<P>A direct consequence of allowing local functor declarations is the presence
of higher-order functors, even if a bit cumbersome:</P>

<PRE class=code>
functor F (X : S1) =
struct
    functor G (Y : S2) = struct (* ... *) end
end

structure M = let structure Z = F (X) in G (Y) end</PRE>

<P>Higher-order functors can be created more directly, though. The above
example may be simplified to</P>

<PRE class=code>
functor F (X : S1) (Y : S2) = struct (* ... *) end

structure M = F (X) (Y)</PRE>

<P>Curried application can be written as in the core language, without
parentheses (see <A href="#sugar-parens">below</A>):</P>

<PRE class=code>
structure M = F X Y</PRE>

<P>The class of structure expressions (<I>strexp</I>) has been extended to
include functor expressions. Similar to <TT>fun</TT> declarations,
<TT>functor</TT> declarations are mere derived forms. The declaration for
<TT>F</TT> above is just sugar for:</P>

<PRE class=code>
structure F = fct (X : S1) => fct (Y : S2) => struct (* ... *) end</PRE>

<P>The keyword <TT>fct</TT> starts a functor expression very much like
<TT>fn</TT> begins a function expression in the core language. Functor
expressions can be arbitrarily mixed with other structure expressions. In
contrast to SML, there is no distinction between structure and functor
identifiers (see <A
href="incompatibilities.php3#funid">incompatibilities</A>).</P>

<P class=note><EM>Note:</EM> The keyword <TT>structure</TT> and the syntactic classes
<I>strid</I>, <I>strexp</I>, etc. are kept for compatibility reasons, despite
<TT>module</TT> now being more appropriate.</P>


<?php subsection("higher-sigexp", "Functor signatures") ?>

<P>The syntax for signatures has been extended to contain functor types,
respectively. For example, functor <TT>F</TT> can be described by the following
signature:</P>

<PRE class=code>
structure F : fct (X : S1) -> fct (Y : S2) -> sig (* ... *) end</PRE>

<P>As a derived form the following SML/NJ compatible syntax is provided for
functor descriptions in signatures:</P>

<PRE class=code>
functor F (X : S1) (Y : S2) : sig (* ... *) end</PRE>
  


<?php section("sigmembers", "signature members") ?>

<?php subsection("sigmembers-nested", "Nested signatures") ?>

<P>Like structures and functors, signatures can also be declared anywhere. In
particular, this allows signatures inside structures, and consequently, nested
signatures:</P>

<PRE class=code>
signature S =
sig
    signature T = sig (* ... *) end
end

structure X :> S =
struct
    signature T = sig (* ... *) end
end</PRE>

<P>Nested signatures must always be matched exactly. More precisely, a
signature <I>S</I><SUB>1</SUB> with nested <TT>T</TT> = <I>T</I><SUB>1</SUB> 
matches another signature <I>S</I><SUB>2</SUB> with nested <TT>T</TT> =
<I>T</I><SUB>2</SUB> only if <I>T</I><SUB>1</SUB> matches <I>T</I><SUB>2</SUB>,
<EM>and also</EM> <I>T</I><SUB>2</SUB> matches <I>T</I><SUB>1</SUB>.</P>


<?php subsection("sigmembers-abstract", "Abstract signatures") ?>

<P>Analoguous to types, nested signatures may be specified abstractly:</P>

<PRE class=code>
signature S =
sig
    signature T
    structure X : T
end</PRE>

<P>An abstract signature can be matched by any signature. Abstract signatures
are particularly useful as functor parameters, because they allow declaring
"polymorphic" functors:</P>

<PRE class=code>
functor F (signature S structure X : S) = (* ... *)</PRE>

<P>The Alice <A href="library.php3">library</A> contains several examples of
such polymorphic functors, e.g. the <A href="#lazy"><TT>ByNeed</TT></A> functor
or functors provided by the <A href="library/component-manager.php3">component
manager</A>.</P>

<DIV class=note>

<P>Note that abstract signatures render the type system of Alice undecidable.
We do not consider this a problem in practice, since the simplest program to
make the type checker loop already is highly artificial:</P>

<PRE class=code>
signature I =
sig
    signature A
    functor F(X : sig
                      signature A = A
                      functor F(X : A) : sig end
                  end) : sig end
end

signature J =
sig
    signature A = I
    functor F(X : I) : sig end
end

(* Try to check J &le; I *)
functor Loop(X : J) = X : I</PRE>

<P>Currently, the Alice compiler has no upper limit on the number of
substitutions it does during signature matching, so this example will actually
make it loop.</P>

</DIV>


<!--
<?php section("paramsig", "parameterized signatures") ?>

  <P>
    Functors often require putting <TT>where</TT> constraints on signatures
    to denote exact return types. This can become quite tedious. Alice
    provides an alternative by generalizing signature identifiers to signature
    constructors, parameterized over structure values:
  </P>

  <PRE>
	signature SET(Elem : sig type t end) =
	sig
	    type elem = Elem.t
	    type t
	    (* ... *)
	end

	functor MakeSet(Elem : sig type t end) :> SET(Elem) =
	struct
	    (* ... *)
	end
  </PRE>

  <P>
    The same derived forms as for functor declarations apply, so <TT>SET</TT>
    and <TT>MakeSet</TT> can be defined as:
  </P>

  <PRE>
	signature SET(type t) =
	sig
	    type elem = t
	    type t
	    (* ... *)
	end

	functor MakeSet(type t) :> SET(type t = t) =
	struct
	    (* ... *)
	end
  </PRE>

  <P class=note>
    Caveat: parameterized signatures are not yet properly treated
    in the Alice implementation.
  </P>
-->


<?php section("lazy", "laziness") ?>

<P>Like <A href="futures.php3#lazy">core expressions</A>, modules can be
evaluated lazily. The library provides a polymorphic functor</P>

<PRE class=code>
ByNeed : fct (signature S  functor F () : S) -> S</PRE>

<P>which can be applied to an appropriate functor <TT>F</TT> and returns a lazy
<A href="futures.php3">future</A> of the module resulting from the functor
application <TT>F ()</TT>. Evaluation will be triggered if the result module is
requested.</P>

<P>The most frequent cause of lazy module evaluation is the <A
href="dynamics.php3#components">component system</A>. Every structure that is
imported from another component is evaluated lazily.</P>


<?php subsection("lazy-longids", "Lazy structure access") ?>

<P>Long identifiers have lazy semantics: accessing a structure <TT>X</TT> via
the dot notation <TT>X.l</TT> does <EM>not</EM> request <TT>X</TT>. The
structure is only requested if <TT>X.l</TT> itself is requested.</P>



<?php section("fixity", "fixity specifications") ?>

<P>Signatures may contain fixity specifications:</P>

<PRE class=code>
signature S =
sig
    type t
    infix 2 ++
    val x :    t
    val op++ : t * t -> t
end</PRE>

<P>To match a signature with infix specifications, a structure must provide the
same infix status directives. The infix environment is part of a structures
principal signature.</P>


<?php subsection("fixity-open", "Opening structures") ?>

<P>Opening a structure with infix specifications pulls in the according infix
status into the local environment:</P>

<PRE class=code>
structure M :> S = struct (* ... *) end

open M
val z = x ++ x</PRE>

<P>Some structures of the Alice library, e.g. in the <A
href="library/linear.php3">linear constraint</A> component, contain infix
declarations that can be used comfortably this way.</P>

<P class=note><EM>Note:</EM> this feature produces a syntactic <A
href="incompatibilities.php3#openinfix">incompatibility</A> with SML showing up
in some rare cases.</P>



<?php section("sugar", "syntactic enhancements") ?>

<?php subsection("sugar-parens", "Parentheses") ?>

<P>Parentheses may be used freely in module and signature expressions:</P>

<PRE class=code>
structure X :> (S' where type t = int) = (F (A))</PRE>

<P>Parentheses may be dropped from functor arguments:</P>

<PRE class=code>
structure Y = F A B</PRE>

<P>The derived form for functor arguments, allowing a list <I>dec</I> of
declarations being given instead of a structure expression, has been
generalized. In a structure expression, parentheses may either enclose another
<I>strexp</I>, or a <I>dec</I>. For example,</P>

<PRE class=code>
structure Z = (type t = int val x = 9)</PRE>

<P>Analogously, in a signature expression, parentheses may enclose either
another <I>sigexp</I>, or a <I>spec</I>:</P>

<PRE class=code>
signature S = (type t val x : int)</PRE>


<?php subsection("sugar-wildcards", "Module wildcards") ?>

<P>Structure bindings may contain a wildcard instead of a structure
identifier:</P>

<PRE class=code>
structure _ = Pickle.SaveVal (type t = int  val x = 43)</PRE>

<P>In this example, the functor application is performed solely for its side
effect, and it does not return any interesting result.</P>

<P>Similarly, wildcards are allowed for functor parameters:</P>

<PRE class=code>
functor F (_ : S) = struct (* don't actually need argument *) end</PRE>

<P>This is particularly useful in signatures:</P>

<PRE class=code>
signature FF = fct (_ : A) -> B</PRE>


<?php subsection("sugar-withtype", "Recursion using <TT>withtype</TT>") ?>

<P>As in the core language, datatype specifications may be made recursive with
type declarations using the <TT>withtype</TT> keyword:</P>

<PRE class=code>
signature S =
sig
    datatype 'a tree   = TREE of 'a forest
    withtype 'a forest = 'a tree list
end</PRE>


<?php subsection("sugar-op", "The <TT>op</TT> keyword") ?>

<P>The keyword <TT>op</TT> is allowed in value, constructor and exception
specifications:</P>

<PRE class=code>
signature S =
sig
    datatype 'a list = nil | op:: of 'a * 'a list
    val op+ : int * int -> int
    exception op!!!
end</PRE>



<?php section("syntax", "syntax") ?>

<P>The syntax for modules very much resembles the syntax of core language
expressions. Derived forms have been marked with (*).</P>


<?php subsection("syntax-structs", "Structures") ?>

<TABLE class=bnf>
  <TR>
    <TD> <I>atstrexp</I> </TD>
    <TD align="center">::=</TD>
    <TD> <TT>struct</TT> <I>dec</I> <TT>end</TT> </TD>
    <TD> structure </TD>
  </TR>
  <TR>
    <TD></TD> <TD></TD>
    <TD> <I>longstrid</I> </TD>
    <TD> structure identifier </TD>
  </TR>
  <TR>
    <TD></TD> <TD></TD>
    <TD> <TT>let</TT> <I>dec</I> <TT>in</TT> <I>strexp</I> <TT>end</TT> </TD>
    <TD> local declarations </TD>
  </TR>
  <TR>
    <TD></TD> <TD></TD>
    <TD> <TT>(</TT> <I>strexp</I> <TT>)</TT> </TD>
    <TD> parentheses </TD>
  </TR>
  <TR>
    <TD></TD> <TD></TD>
    <TD> <TT>(</TT> <I>dec</I> <TT>)</TT> </TD>
    <TD> structure (*) </TD>
  </TR>
  <TR></TR>
  <TR>
    <TD> <I>appstrexp</I> </TD>
    <TD align="center">::=</TD>
    <TD> <I>atstrexp</I> </TD>
    <TD> </TD>
  </TR>
  <TR>
    <TD></TD> <TD></TD>
    <TD> <I>appstrexp</I> <I>atstrexp</I> </TD>
    <TD> functor application </TD>
  </TR>
  <TR></TR>
  <TR>
    <TD> <I>strexp</I> </TD>
    <TD align="center">::=</TD>
    <TD> <I>appstrexp</I> </TD>
    <TD> </TD>
  </TR>
  <TR>
    <TD></TD> <TD></TD>
    <TD> <I>strexp</I> <TT>:</TT> <I>sigexp</I> </TD>
    <TD> transparent constraint </TD>
  </TR>
  <TR>
    <TD></TD> <TD></TD>
    <TD> <I>strexp</I> <TT>:></TT> <I>sigexp</I> </TD>
    <TD> opaque constraint </TD>
  </TR>
  <TR>
    <TD></TD> <TD></TD>
    <TD> <TT>fct</TT> <I>strpat</I> <TT>=></TT> <I>strexp</I> </TD>
    <TD> functor </TD>
  </TR>
  <TR></TR>
  <TR>
    <TD> <I>strpat</I> </TD>
    <TD align="center">::=</TD>
    <TD> <TT>(</TT> <I>strid</I> <TT>:</TT> <I>sigexp</I> <TT>)</TT> </TD>
    <TD> parameter </TD>
  </TR>
  <TR>
    <TD></TD> <TD></TD>
    <TD> <TT>(</TT> <TT>_</TT> <TT>:</TT> <I>sigexp</I> <TT>)</TT> </TD>
    <TD> anonymous parameter (*) </TD>
  </TR>
  <TR>
    <TD></TD> <TD></TD>
    <TD> <TT>(</TT> <I>spec</I> <TT>)</TT> </TD>
    <TD> signature as parameter (*) </TD>
  </TR>
</TABLE>


<?php subsection("syntax-sigs", "Signatures") ?>

<TABLE class=bnf>
  <TR>
    <TD> <I>atsigexp</I> </TD>
    <TD align="center">::=</TD>
    <TD> <TT>any</TT> </TD>
    <TD> top </TD>
  </TR>
  <TR>
    <TD></TD> <TD></TD>
    <TD> <TT>sig</TT> <I>spec</I> <TT>end</TT> </TD>
    <TD> ground signature </TD>
  </TR>
  <TR>
    <TD></TD> <TD></TD>
    <TD> <I>longsigid</I> </TD>
    <TD> signature identifier </TD>
  </TR>
<!--
  <TR>
    <TD></TD> <TD></TD>
    <TD> <TT>let</TT> <I>dec</I> <TT>in</TT> <I>sigexp</I> <TT>end</TT> </TD>
    <TD> local declarations </TD>
  </TR>
-->
  <TR>
    <TD></TD> <TD></TD>
    <TD> <TT>(</TT> <I>sigexp</I> <TT>)</TT> </TD>
    <TD> parentheses </TD>
  </TR>
  <TR>
    <TD></TD> <TD></TD>
    <TD> <TT>(</TT> <I>spec</I> <TT>)</TT> </TD>
    <TD> signature (*) </TD>
  </TR>
  <TR></TR>
<!--
  <TR>
    <TD> <I>appsigexp</I> </TD>
    <TD align="center">::=</TD>
    <TD> <I>atsigexp</I> </TD>
    <TD> </TD>
  </TR>
  <TR>
    <TD></TD> <TD></TD>
    <TD> <I>appsigexp</I> <I>atstrexp</I> </TD>
    <TD> signature application </TD>
  </TR>
  <TR></TR>
  <TR>
    <TD> <I>sigexp</I> </TD>
    <TD align="center">::=</TD>
    <TD> <I>appsigexp</I> </TD>
    <TD> </TD>
  </TR>
-->
  <TR>
    <TD> <I>sigexp</I> </TD>
    <TD align="center">::=</TD>
    <TD> <I>atsigexp</I> </TD>
    <TD> </TD>
  </TR>
  <TR>
    <TD></TD> <TD></TD>
    <TD> <TT>fct</TT> <I>strpat</I> <TT>-></TT> <I>sigexp</I> </TD>
    <TD> functor </TD>
  </TR>
  <TR>
    <TD></TD> <TD></TD>
    <TD> <I>sigexp</I> <TT>where</TT> <I>rea</I> </TD>
    <TD> specialization </TD>
  </TR>
  <TR></TR>
  <TR>
    <TD> <I>rea</I> </TD>
    <TD align="center">::=</TD>
<!--
    <TD> <TT>val</TT> <I>longvid</I> <TT>=</TT> <I>longvid</I> </TD>
    <TD> </TD>
  </TR>
  <TR>
    <TD></TD> <TD></TD>
    <TD> <TT>constructor</TT> <I>longvid</I> <TT>=</TT> <I>longvid</I> </TD>
    <TD> </TD>
  </TR>
  <TR>
    <TD></TD> <TD></TD>
-->
    <TD> <TT>type</TT> <I>tyvarseq</I> <I>longtycon</I>
         <TT>=</TT> <I>ty</I> </TD>
    <TD> </TD>
  </TR>
<!--
  <TR>
    <TD></TD> <TD></TD>
    <TD> <TT>structure</TT> <I>longstrid</I><SUB>1</SUB> <TT>=</TT> <I>longstrid</I><SUB>2</SUB> </TD>
    <TD> </TD>
  </TR>
  <TR>
    <TD></TD> <TD></TD>
    <TD> <TT>signature</TT> <I>longsigid</I>
         <I>strpat</I><SUB>1</SUB> ... <I>strpat</I><SUB><I>n</I></SUB>
         <TT>=</TT> <I>sigexp</I> </TD>
    <TD> signature (<I>n</I>&ge;0) </TD>
  </TR>
  <TR></TR>
-->
</TABLE>


<?php subsection("syntax-specs", "Specifications") ?>

<TABLE class=bnf>
  <TR>
    <TD> <I>spec</I> </TD>
    <TD align="center">::=</TD>
    <TD> ... </TD>
    <TD> </TD>
  </TR>
  <TR>
    <TD></TD> <TD></TD>
    <TD> <TT>functor</TT> <I>fundesc</I> </TD>
    <TD> functor specification (*) </TD>
  </TR>
  <TR>
    <TD></TD> <TD></TD>
    <TD> <TT>signature</TT> <I>sigdesc</I> </TD>
    <TD> signature specification </TD>
  </TR>
  <TR></TR>
  <TR>
    <TD> <I>fundesc</I> </TD>
    <TD align="center">::=</TD>
    <TD> <I>strid</I> <I>strpat</I><SUB>1</SUB> ... <I>strpat</I><SUB><I>n</I></SUB>
         <TT>:</TT> <I>sigexp</I>
         &lt;<TT>and</TT> <I>fundesc</I>&gt; </TD>
    <TD> functor description (<I>n</I>&ge;1) (*) </TD>
  </TR>
  <TR></TR>
  <TR>
    <TD> <I>sigdesc</I> </TD>
    <TD align="center">::=</TD>
    <TD> <I>sigid</I> &lt;<TT>=</TT> <I>sigexp</I>&gt;
         &lt;<TT>and</TT> <I>sigdesc</I>&gt; </TD>
    <TD> signature description </TD>
  </TR>
<!--
  <TR>
    <TD> <I>sigdesc</I> </TD>
    <TD align="center">::=</TD>
    <TD> <I>sigid</I> <I>strpat</I><SUB>1</SUB> ... <I>strpat</I><SUB><I>n</I></SUB>
         &lt;<TT>=</TT> <I>sigexp</I>&gt;
         &lt;<TT>and</TT> <I>sigdesc</I>&gt; </TD>
    <TD> signature description (<I>n</I>&ge;0) </TD>
  </TR>
-->
</TABLE>


<?php subsection("syntax-decs", "Declarations") ?>

<TABLE class=bnf>
  <TR>
    <TD> <I>strbind</I> </TD>
    <TD align="center">::=</TD>
    <TD> ... </TD>
    <TD> </TD>
  </TR>
  <TR>
    <TD></TD> <TD></TD>
    <TD> <TT>_</TT> &lt;<TT>:</TT> <I>sigexp</I>&gt; <TT>=</TT> <I>strexp</I>
         &lt;<TT>and</TT> <I>strbind</I>&gt; </TD>
    <TD> anonymous structure (*) </TD>
  </TR>
  <TR></TR>
  <TR valign=baseline>
    <TD> <I>funbind</I> </TD>
    <TD align="center">::=</TD>
    <TD> <I>strid</I> <I>strpat</I><SUB>1</SUB> ... <I>strpat</I><SUB><I>n</I></SUB>
         <TT>=</TT> <I>strexp</I>
         &lt;<TT>and</TT> <I>funbind</I>&gt; </TD>
    <TD> functor binding (<I>n</I>&ge;1) (*) </TD>
  </TR>
<!--
  <TR></TR>
  <TR>
    <TD> <I>sigbind</I> </TD>
    <TD align="center">::=</TD>
    <TD> <I>sigid</I> <I>strpat</I><SUB>1</SUB> ... <I>strpat</I><SUB><I>n</I></SUB>
         <TT>=</TT> <I>sigexp</I>
         &lt;<TT>and</TT> <I>sigbind</I>&gt; </TD>
    <TD> signature binding (<I>n</I>&ge;0) </TD>
  </TR>
-->
</TABLE>


<?php subsection("syntax-derived", "Derived forms") ?>

<TABLE class=bnf>
  <TR>
    <TD> <TT>(</TT> <I>dec</I> <TT>)</TT> </TD>
    <TD> ==> </TD>
    <TD> <TT>struct</TT> <I>dec</I> <TT>dec</TT> </TD>
  </TR>
  <TR>
    <TD> <TT>(</TT> <TT>_</TT> <TT>:</TT> <I>sigexp</I> <TT>)</TT> </TD>
    <TD> ==> </TD>
    <TD> <TT>(</TT> <I>strid</I> <TT>:</TT> <I>sigexp</I> <TT>)</TT> 
         <SUP>1</SUP> </TD>
  </TR>
  <TR>
    <TD> <TT>(</TT> <I>spec</I> <TT>)</TT> </TD>
    <TD> ==> </TD>
    <TD> <TT>(</TT> <I>strid</I> <TT>:</TT> <TT>(</TT> <I>spec</I> <TT>))</TT> 
         <SUP>1</SUP><SUP>2</SUP> </TD>
  </TR>
  <TR></TR>
  <TR>
    <TD> <TT>functor</TT> <I>funbind</I> </TD>
    <TD> ==> </TD>
    <TD> <TT>structure</TT> <I>funbind</I> </TD>
  </TR>
  <TR>
    <TD> <I>strid</I> <I>strpat</I><SUB>1</SUB> ... <I>strpat</I><SUB><I>n</I></SUB>
         <TT>=</TT> <I>strexp</I>
         &lt;<TT>and</TT> <I>funbind</I>&gt; </TD>
    <TD> ==> </TD>
    <TD> <I>strid</I> <TT>=</TT>
         <TT>fct</TT> <I>strpat</I><SUB>1</SUB> <TT>=></TT> ...
	 <TT>fct</TT> <I>strpat</I><SUB><I>n</I></SUB> <TT>=></TT> <I>strexp</I>
	 &lt;<TT>and</TT> <I>funbind</I>&gt; </TD>
  </TR>
  <TR>
    <TD> <TT>_</TT> &lt;<TT>:</TT> <I>sigexp</I>&gt; <TT>=</TT> <I>strexp</I>
         &lt;<TT>and</TT> <I>strbind</I>&gt; </TD>
    <TD> ==> </TD>
    <TD> <I>strid</I> &lt;<TT>:</TT> <I>sigexp</I>&gt; <TT>=</TT> <I>strexp</I>
         &lt;<TT>and</TT> <I>strbind</I>&gt; <SUP>1</SUP> </TD>
  </TR>
  <TR></TR>
  <TR>
    <TD> <TT>(</TT> <I>spec</I> <TT>)</TT> </TD>
    <TD> ==> </TD>
    <TD> <TT>sig</TT> <I>spec</I> <TT>end</TT> </TD>
  </TR>
  <TR></TR>
  <TR>
    <TD> <TT>functor</TT> <I>fundesc</I> </TD>
    <TD> </TD>
    <TD> <TT>structure</TT> <I>fundesc</I> </TD>
  </TR>
  <TR>
    <TD> <I>strid</I> <I>strpat</I><SUB>1</SUB> ... <I>strpat</I><SUB><I>n</I></SUB>
         <TT>:</TT> <I>sigexp</I>
         &lt;<TT>and</TT> <I>fundesc</I>&gt; </TD>
    <TD> ==> </TD>
    <TD> <I>strid</I> <TT>:</TT>
	 <TT>fct</TT> <I>strpat</I><SUB>1</SUB> <TT>-></TT> ...
	 <TT>fct</TT> <I>strpat</I><SUB><I>n</I></SUB> <TT>-></TT> <I>sigexp</I>
         &lt;<TT>and</TT> <I>fundesc</I>&gt; </TD>
  </TR>
</TABLE>

<P><SUP>1</SUP>) The identifier <I>strid</I> is new.</P>

<P><SUP>2</SUP>) If the <I>strpat</I> occurs in a functor expression
<TT>fct</TT> <I>strpat</I> <TT>=></TT> <I>strexp</I>, then <I>strexp</I> is
rewritten to <I>strexp'</I> by replacing all occurances of identifiers <I>x</I>
bound in <I>spec</I> to <I>strid</I><TT>.</TT><I>x</I>. Likewise, if it occurs
in a functor signature <TT>fct</TT> <I>strpat</I> <TT>-></TT> <I>sigexp</I>,
then <I>sigexp</I> is rewritten to <I>sigexp'</I> by similar replacement.</P>


<?php footing() ?>
