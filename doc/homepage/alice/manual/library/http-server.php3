<?php include("macros.php3"); ?>
<?php heading("The HttpServer structure",
	      "The <TT>HttpServer</TT> structure") ?>

<?php section("synopsis", "synopsis") ?>

  <PRE>
    signature HTTP_SERVER
    structure HttpServer : HTTP_SERVER</PRE>

  <P>
    This structure provides a simple, extensible server for the HTTP
    protocol as specified in RFC&nbsp;2616.
  </P>

  <P>
    See also:
    <A href="url.php3"><TT>Url</TT></A>,
    <A href="http.php3"><TT>Http</TT></A>,
    <A href="http-client.php3"><TT>HttpClient</TT></A>,
    <A href="socket.php3"><TT>Socket</TT></A>
  </P>

<?php section("import", "import") ?>

  <PRE>
    import structure HttpServer from "x-alice:/lib/system/HttpServer"
    import signature HTTP_SERVER from "x-alice:/lib/system/HTTP_SERVER-sig"</PRE>

<?php section("interface", "interface") ?>

  <PRE>
    signature HTTP_SERVER =
    sig
	type <A href="#handler">handler</A> = <A href="http.php3#request">Http.request</A> -> <A href="http.php3#response">Http.response</A>

	val <A href="#start">start</A> : int option -> int
	val <A href="#register">register</A> : <A href="url.php3#t">Url.t</A> * handler -> unit
    end</PRE>

<?php section("description", "description") ?>

  <DL>
    <DT>
      <TT>type <A name="handler">handler</A> =
	<A href="http.php3#request">Http.request</A> ->
	<A href="http.php3#response">Http.response</A></TT>
    </DT>
    <DD>
      <P>The type of handlers for HTTP requests.</P>
    </DD>

    <DT>
      <TT><A name="start">start</A> <I>portOpt</I></TT>
    </DT>
    <DD>
      <P>starts a HTTP server and lets it listen for connections in
	a concurrent thread.  If <TT><I>portOpt</I></TT> is <TT>SOME
	<I>port</I></TT>, tries to listen on <TT><I>port</I></TT>, else
	selects an available port.  Returns the port on which it listens
	for request.</P>
    </DD>

    <DT>
      <TT><A name="register">register</A> (<I>url</I>, <I>handler</I>)</TT>
    </DT>
    <DD>
      <P>registers <TT><I>handler</I></TT> for requests make to
	<TT><I>url</I></TT>.  Only the path component or <TT><I>url</I></TT>
	is significant.</P>
    </DD>
  </DL>

<?php section("examples", "examples") ?>

  <P>
    The following demonstrates how to start a simple HTTP server which
    interprets all requested URLs as files under a <EM>document root</EM>;
    it just returns the file with type <TT>text/plain</TT>.  If the file
    could not be found, it returns a <TT>404 Not Found</TT> response.
  </P>

  <P><A href="HttpServerExample.aml">Download full source code</A></P>

<PRE>
val documentRoot = "/tmp/httproot"

val notFoundDocument = "The requested document could not be found\n"

fun documentHandler (request: Http.request) =
    let
	val relFile = Url.toString (Url.setQuery (#uri request, NONE))
	val file = TextIO.openIn (documentRoot ^ relFile)
	val body = TextIO.inputAll file
    in
	TextIO.closeIn file;
	Http.makeResponse
	    {statusCode = 200, contentType = "text/plain", body}
    end handle IO.Io {...} =>
	Http.makeResponse
	    {statusCode = 404, contentType = "text/plain",
	     body = notFoundDocument}

val port = HttpServer.start NONE
val _ = HttpServer.register (Url.empty, documentHandler)
val _ = TextIO.print ("started server at port " ^
		      Int.toString port ^ "\n")
</PRE>

<?php footing() ?>
