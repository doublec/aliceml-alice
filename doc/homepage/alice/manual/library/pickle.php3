<?php include("macros.php3"); ?>
<?php heading("The Pickle structure", "The <TT>Pickle</TT> structure") ?>

<?php section("synopsis", "synopsis") ?>

  <PRE>
    signature PICKLE
    structure Pickle : PICKLE
  </PRE>

  <P>
    The <TT>Pickle</TT> structure provides functionality for <EM>pickling</EM>
    and unpickling arbitrary values and modules. A <EM>pickle</EM> is a
    serialized and closed representation of a (higher-order) value, stored
    in a file. Pickles can be used to exchange arbitrary data structures or
    even complete abstract type implementations between processes.
  </P>

  <P>
    Pickles do not contain any futures.
    Instead, pickling requests all futures contained in the closure of the
    value.
  </P>

  <P>
    Pickles may contain stateful values, like references or arrays. Pickling
    a stateful data structure implies a copying semantics: each time the
    value is unpickled, a fresh copy of all contained stateful values will be
    created. Sharing between stateful object is maintained inside a pickle,
    though.
  </P>

  <P>
    A pickle may not contain local resources, so-called <EM>sited</EM> values
    (e.g. streams associated with files, first-class threads, or functions or
    modules containing creating such values).
    Any attempt to pickle a value whose closure contains sited values will
    result in an <TT>Io</TT> exception being raised, with the exception
    <TT>Sited</TT> indicating the cause.
  </P>

  <P>See also:
    <A href="package.php3"><TT>Package</TT></A>,
    <A href="component.php3"><TT>Component</TT></A>,
    <A href="future.php3"><TT>Future</TT></A>
  </P>

<?php section("import", "import") ?>

  <P>
    Imported implicitly.
  </P>

<?php section("interface", "interface") ?>

  <PRE>
    signature PICKLE =
    sig
	exception Sited

	val extension : string

	val save :    string * package -> unit
	val load :    string -> package
        val saveVal : string * Package.val_package -> unit
        val loadVal : string -> Package.val_package

	functor Save(val file : string signature S structure X : S) : any
	functor Load(val file : string signature S) : S

	functor SaveVal(val file : string type t val x : t) : any
	functor LoadVal(val file : string type t) : (val x : t)
    end
  </PRE>

<?php section("description", "description") ?>

  <DL>
    <DT>
      <TT>exception Sited</TT>
    </DT>
    <DD>
      <P>used by the <TT>save</TT> operation to indicate
	that a first-class component contains sited data structures.  This
	exception is never raised directly; it only appears as the <TT
	>cause</TT> of an <TT><A href="io.php3">IO.Io</A></TT> exception.
	Equal to <TT>Component.Sited</TT>.</P>
    </DD>

    <DT>
      <TT>extension</TT>
    </DT>
    <DD>
      <P>The default file name extension used for pickle files on the host
      system. Equal to <TT>Component.extension</TT>.</P>
    </DD>

    <DT>
      <TT>save (<I>name</I>, <I>package</I>)</TT>
    </DT>
    <DD>
      <P>Saves <TT><I>package</I></TT> to the file named <TT><I>name</I></TT>.
      Synchronizes on all futures contained in (the closure of) the package.
      Raises <TT>IO.Io</TT> if writing the pickle fails. Particular causes
      for failure may be that <TT><I>package</I></TT> refers to sited values.</P>
    </DD>

    <DT>
      <TT>load <I>name</I></TT>
    </DT>
    <DD>
      <P>Loads a package from the file denoted by the URI <TT><I>name</I></TT>.
      The pickle is located and loaded as a component, via the function <A
      href="component.php3#load"><TT>Component.load</TT></A>.
      Raises <TT>IO.Io</TT> if reading or evaluating the component fails.
      Particular causes
      for failure may be that file is corrupt, i.e. not a valid pickle file.
      This is indicated by the exception <TT>Component.Corrupt</TT>.</P>
    </DD>

    <DT>
      <TT>saveVal (<I>name</I>, <I>package</I>)</TT> <BR>
      <TT>loadVal <I>name</I></TT>
    </DT>
    <DD>
      <P>Like <TT>save</TT> and <TT>load</TT>, but operate on value
      packages.</P>
    </DD>

    <DT>
      <TT>Save (val file = <I>name</I>  signature S = <I>S</I>  structure X = <I>X</I>)</TT>
    </DT>
    <DD>
      <P>Creates a package of module <TT><I>X</I></TT> under signature
      <TT><I>S</I></TT> and writes it to the file named <TT><I>name</I></TT>,
      as with <TT>save</TT>. Equivalent to</P>
      <PRE>
	save (<I>name</I>, pack <I>X</I> :> <I>S</I>)</PRE>
    </DD>

    <DT>
      <TT>Load (val file = <I>name</I>  signature S = <I>S</I>)</TT>
    </DT>
    <DD>
      <P>Reads a package from the file named <TT><I>name</I></TT>, as with
      <TT>load</TT> and tries to unpack it under signature <TT><I>S</I></TT>.
      Raises <TT>Package.Mismatch</TT> if unpacking fails. Equivalent to</P>
      <PRE>
	unpack (load <I>file</I>) : <I>S</I></PRE>
    </DD>

    <DT>
      <TT>SaveVal (val file = <I>name</I>  type t = <I>t</I>  val x = <I>v</I>)</TT> <BR>
      <TT>LoadVal (val file = <I>name</I>  type t = <I>t</I>)</TT>
    </DT>
    <DD>
      <P>Similar to <TT>Save</TT> and <TT>Load</TT>, but operate on value
      packages, corresponding to <TT>saveVal</TT> and <TT>loadVal</TT>. The
      functor <TT>LoadVal</TT> raises <TT>Package.MismatchVal</TT> if the
      found package does not possess the desired type.</P>
    </DD>
  </DL>

<?php footing() ?>
