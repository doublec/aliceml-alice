<?php include("macros.php3"); ?>
<?php heading("The HttpClient structure",
	      "The <TT>HttpClient</TT> structure") ?>

<?php section("synopsis", "synopsis") ?>

  <PRE>
    signature HTTP_CLIENT
    structure HttpClient : HTTP_CLIENT</PRE>

  <P>
    This structure implements a simple client for the HTTP protocol
    as specified in RFC&nbsp;2616.  Connections are only created and
    maintained open for issuing a single request and reading a single
    response.
  </P>

  <P>
    Where a request is constructed, the current implementation inserts
    a <TT>User-Agent</TT> of <TT>Stockhausen/1.0</TT> and uses protocol
    version 1.1.
  </P>

  <P>
    See also:
    <A href="url.php3"><TT>Url</TT></A>,
    <A href="http.php3"><TT>Http</TT></A>,
    <A href="http-server.php3"><TT>HttpServer</TT></A>,
    <A href="resolver.php3"><TT>Resolver</TT></A>,
    <A href="socket.php3"><TT>Socket</TT></A>
  </P>

<?php section("import", "import") ?>

  <PRE>
    import structure HttpClient from "x-alice:/lib/system/HttpClient"
    import signature HTTP_CLIENT from "x-alice:/lib/system/HTTP_CLIENT-sig"</PRE>

<?php section("interface", "interface") ?>

  <PRE>
    signature HTTP_CLIENT =
    sig
	type <A href="#document">document</A> = {contentType : string, body : string}

	exception <A href="#Authority">Authority</A>

	val <A href="#request">request</A> : <A href="url.php3#t">Url.t</A> * <A href="http.php3#request">Http.request</A> -> <A href="http.php3#response">Http.response</A>
	val <A href="#get">get</A> : <A href="url.php3#t">Url.t</A> -> <A href="http.php3#response">Http.response</A>
	val <A href="#post">post</A> : <A href="url.php3#t">Url.t</A> * document -> <A href="http.php3#response">Http.response</A>
    end</PRE>

<?php section("description", "description") ?>

  <DL>
    <DT>
      <TT>type <A name="document">document</A> =
	{contentType : string, body : string}</TT>
    </DT>
    <DD>
      <P>The type of documents as provided in a <TT>POST</TT> request.</P>
    </DD>

    <DT>
      <TT>exception <A name="Authority">Authority</A></TT>
    </DT>
    <DD>
      <P>indicates that a given URL did either not contain an authority
	or that it was not well-formed (for instance, a port number was
	supplied, but it was no valid integer).</P>
    </DD>

    <DT>
      <TT><A name="request">request</A> (<I>url</I>, <I>request</I>)</TT>
    </DT>
    <DD>
      <P>establishes a connection to the server specified in <I>url</I>,
	issues the <I>request</I>, and returns the response.  Closes the
	connection immediately after reading the response.  Raises
	<TT><A href="#Authority">Authority</A></TT> if <I>url</I> does
	not specify a well-formed authority.</P>
    </DD>

    <DT>
      <TT><A name="get">get</A> <I>url</I></TT>
    </DT>
    <DD>
      <P>establishes a connection to the server specified in <I>url</I>,
	issues a <TT>GET</TT> request, and returns the response.  Closes
	the connection immediately after reading the response.  Raises
	<TT><A href="#Authority">Authority</A></TT> if <I>url</I> does
	not specify a well-formed authority.</P>
    </DD>

    <DT>
      <TT><A name="post">post</A> (<I>url</I>, <I>doc</I>)</TT>
    </DT>
    <DD>
      <P>establishes a connection to the server specified in <I>url</I>,
	issues a <TT>POST</TT> request with <I>doc</I>, and returns the
	response.  Closes the connection immediately after reading the
	response.  Raises <TT><A href="#Authority">Authority</A></TT>
	if <I>url</I> does not specify a well-formed authority.</P>
    </DD>
  </DL>

<?php section("examples", "examples") ?>

  <P>
    The following example implements a simple stand-alone application
    that takes a URL on its command line, issues a corresponding
    <TT>GET</TT> request, and dumps the response status and headers
    to <TT>TextIO.stdErr</TT> and the document to <TT>TextIO.stdOut</TT>.
  </P>

  <P><A href="HttpClientExample.aml">Download full source code</A></P>

<PRE>
fun usage () =
    TextIO.output (TextIO.stdErr,
		   "Usage: " ^ CommandLine.name () ^ " <url>\n")

fun main [url] =
    let
	val response = HttpClient.get (Url.fromString url)
    in
	TextIO.output
	    (TextIO.stdErr, Int.toString (#statusCode response) ^ " " ^
			    #reasonPhrase response ^ "\n");
	Http.StringMap.appi
	    (fn (name, value) =>
		TextIO.output (TextIO.stdErr,
			       name ^ ": " ^ value ^ "\n"))
	    (#headers response);
	TextIO.output (TextIO.stdErr, "\n");
	TextIO.print (#body response);
	OS.Process.success
    end
  | main _ = (usage (); OS.Process.failure)

val _ = OS.Process.exit (main (CommandLine.arguments ()))
</PRE>

<?php footing() ?>
