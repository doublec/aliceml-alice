<?php include("macros.php3"); ?>
<?php heading("The INTEGER signature", "The <TT>INTEGER</TT> signature") ?>

<?php section("synopsis", "synopsis") ?>

  <PRE>
    signature INTEGER
    structure Int : INTEGER where type int = int
    structure LargeInt : INTEGER = Int
    structure Position : INTEGER = Int
  </PRE>

  <P>
    An extended version of the
    <A href="http://www.dina.kvl.dk/~sestoft/sml/integer.html">Standard ML
    Basis' <TT>INTEGER</TT></A> signature.
  </P>

  <P>See also:
    <A href="word.php3"><TT>WORD</TT></A>
  </P>

<?php section("import", "import") ?>

  <P>
    Imported implicitly.
  </P>

<?php section("interface", "interface") ?>

  <PRE>
    signature INTEGER =
    sig
	eqtype int
	type t = int

	val minInt :     int option
	val maxInt :     int option
	val precision :  Int.int option

	val toInt :      int -> Int.int
	val fromInt :    Int.int -> int
	val toLarge :    int -> LargeInt.int
	val fromLarge :  LargeInt.int -> int

	val ~ :          int -> int
	val op + :       int * int -> int
	val op - :       int * int -> int
	val op * :       int * int -> int
	val op div :     int * int -> int
	val op mod :     int * int -> int
	val op quot :    int * int -> int
	val op rem :     int * int -> int

	val op < :       int * int -> bool
	val op > :       int * int -> bool
	val op <= :      int * int -> bool
	val op >= :      int * int -> bool
	val equal :      int * int -> bool
	val compare :    int * int -> order
	val hash :       int -> int

	val abs :        int -> int
	val min :        int * int -> int
	val max :        int * int -> int
	val sign :       int -> Int.int
	val sameSign :   int * int -> bool

	val toString :   int -> string
	val fromString : string -> int option
	val fmt :        StringCvt.radix -> int -> string
	val scan :       StringCvt.radix -> (char,'a) StringCvt.reader -> (int,'a) StringCvt.reader
    end
  </PRE>

<?php section("description", "description") ?>

  <P>
    Items not described here are as in the 
    <A href="http://www.dina.kvl.dk/~sestoft/sml/integer.html">Standard ML
    Basis' <TT>INTEGER</TT></A> signature.
  </P>

  <DL>
    <DT>
      <TT>type t = int</TT>
    </DT>
    <DD>
      <P>A local synonym for type <TT>int</TT>.</P>
    </DD>

    <DT>
      <TT>equal (<I>i1</I>, <I>i2</I>)</TT>
    </DT>
    <DD>
      <P>An explicit equality function on integers. Equivalent to <TT>op=</TT>.</P>
    </DD>

    <DT>
      <TT>hash <I>i</I></TT>
    </DT>
    <DD>
      <P>A hash function for integers. Returns <TT><I>i</I></TT> itself.</P>
    </DD>

    <DT>
      <TT>fromString <I>s</I></TT> <BR>
      <TT>scan <I>getc</I> <I>strm</I></TT>
    </DT>
    <DD>
      <P>Like specified in the <A href="http://www.dina.kvl.dk/~sestoft/sml/integer.html#SIG:INTEGER.fromString:VAL">Standard ML
      Basis</A>, except that underscores are allowed to separate digits.
      The <TT>scan</TT> function thus excepts the following formats:</P>
      <PRE>
        StringCvt.BIN   [+~-]?[0-1_]*[0-1][0-1_]*
	StringCvt.OCT   [+~-]?[0-7_]*[0-7][0-7_]*
	StringCvt.DEC   [+~-]?[0-9_]*[0-9][0-9_]*
	StringCvt.HEX   [+~-]?(0x|0X)?[0-9a-fA-F_]*[0-9a-fA-F][0-9a-fA-F_]*</PRE>
      <P>The expression <TT>fromString <I>s</I></TT> is equivalent to
      <TT>StringCvt.scanString (scan DEC) s</TT>.</P>
    </DD>
  </DL>

<?php footing() ?>
