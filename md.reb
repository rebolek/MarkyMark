REBOL[
	Title: "Rebol Markdown Parser"
	File: %md.reb
	Author: "Boleslav Březovský"
	Date: 7-3-2014
;	Type: 'module
	Exports: [markdown]
	Options: [isolate]
	To-do: [
		"function to produce rule wheter to continue on start-para or not"
		"EMIT-NEWLINE: to emit neline AND setsome bit that newline was emitted"
	]
	Known-bugs: [

	]
	Notes: ["For mardown specification> | <see http://johnmacfarlane.net/babelmark2/faq.html"]
]

xml?: true
start-para?: true
end-para?: false
newline?: true
end-line?: false
lazy?: true
md-buffer: make string! 1000

debug?: false
debug-print: func [value] [if debug? [print value]]

open-para: close-para: none

line-index: has [pos pos2] [
	; TODO: can I do it in one pass?

	; find last newline if present
	pos: find/last md-buffer newline
	default pos md-buffer
	pos: copy/part pos length? pos 	; take just what's after newline
	debug-print ["I-" mold next pos]
	; find last tag if present
	pos2: find/last pos #">"
	default pos2 pos
	debug-print ["I+" mold next pos2]
	length? next pos2
]

; -----

value: copy "" ; FIXME: leak?

rule: func [
	"Make PARSE rule with local variables"
	local 	[word! block!]  "Local variable(s)"
	rule 	[block!]		"PARSE rule"
][
	if word? local [local: reduce [local]]
	use local reduce [rule]
]

emit: func [value] [ 
	newline?: false
	start-para
	append md-buffer value
]

emit-newline: does [
	debug-print "::EMIT newline"
	append md-buffer newline
	newline?: true
	end-line?: false
]

emit-line: func [value] [
	emit value
	emit-newline
]

emit-entity: function [entity] [
	entity: min 65533 to integer! entity
	emit either out: select numeric-entities entity [
		rejoin [#"&" out #";"]
	] [
		to char! entity
	] 
]

remove-last-newline: does [
	if equal? newline last md-buffer [remove back tail md-buffer]
]

close-tag: func [tag] [head insert copy tag #"/"]

start-para: does [
	if start-para? [
		debug-print "::EMIT open-para"
		start-para?: false 
		end-para?: true
		end-line?: true
		emit open-para
	]
]

end-para: func [
	/trim
] [
	if end-para? [
		; get rid of last newline before closing para
		if trim [remove-last-newline]
		debug-print "::EMIT close-para (function)"
		emit close-para
		emit-newline
		start-para?: true
		end-para?: false
	]
]

;.......... HTML entities

html-entities: load %entities
named-entities: copy html-entities

forskip named-entities 2 [named-entities/2: '|]
take/last named-entities

named-entities-rule: rule [entity] [
	#"&"
	copy entity named-entities
	#";"
	(emit to char! to integer! to issue! select html-entities entity)
]

digit: charset [#"0" - #"9"]
hex-char: charset [#"a" - #"f"]
hex-digit: union digit hex-char

decimal-entities-rule: rule [entity] [
	"&#"
	copy entity 1 8 digit
	#";"
	(emit-entity entity)
]

hexadecimal-entities-rule: rule [entity] [
	"&#x"
	copy entity 1 8 hex-digit
	#";"
	(emit-entity to issue! entity)
]

; TODO: generate following rules to simplify maintance

numeric-entities: [
	34	"quot"
	38 	"amp"
	60 	"lt"
	62 	"gt"
]

entity-descriptors: rule [entity] [
	; copy entity to prevent case
	copy entity some [
		"&lt;"
	|	"&gt;"
	|	"&amp;"
	|	"&quot;"
	]
	(emit entity)
]
entities: [
	#"<" 		(emit "&lt;")
|	#">" 		(emit "&gt;")
|	#"&" 		(emit "&amp;")
|	#"^"" 		(emit "&quot;")
|	#"\" 		(emit #"\")
]
entity-escapes: [
	"\<" 		(emit "&lt;")
|	"\>" 		(emit "&gt;")
|	"\&" 		(emit "&amp;")
|	"\^"" 		(emit "&quot;")
]
escape-set: charset {!#$%'()*+,-./:;=?@[\]^^_`{|}~}
escapes: rule [escape] [
	#"\"
	set escape escape-set
	(debug-print "==ESCAPE matched")
	(start-para)
	(debug-print ["==ESCAPE:" escape])
	(emit escape)
]
escape-entity: [
	#"\" entities
]
percent-encoding: use [char chars] [
	chars: charset {!#$'()*+,;[]\}
	[set char chars (emit join #"%" skip form to-hex to integer! char 15)]
]
entity-rule: [
	hard-linebreak
|	named-entities-rule
|	decimal-entities-rule
|	hexadecimal-entities-rule
|	escape-entity
|	escapes
|	entity-descriptors
|	entity-escapes
|	entities
]
code-entity-rule: [
	hard-linebreak
|	entity-descriptors
|	entities
]
hard-linebreak: [
	if (end-line?)
	#"\" newline 
	(
		debug-print "::EMIT hard linebreak"
		emit <br />
		emit-newline
	)
]
end-line: [newline | end]
numbers: charset [#"0" - #"9"]
letters: charset [#"a" - #"z"]
not-newline: complement charset newline
; some "longer> | <but readable" stuff
plus: #"+"
minus: #"-"
asterisk: #"*"
underscore: #"_"
hash: #"#"
dot: #"."
eq: #"="
lt: #"<"
gt: #">"
whitespace: [space | tab | newline |  #"^K" | #"^L" | #"^M"]
blank-line: [some [space | tab]]
tags: [
	{<article} | {<header} | {<aside} | {<hgroup} | {<blockquote} | {<hr} | {<iframe} | {<body} | {<li} | {<map} | {<button} | 
	{<object} | {<canvas} | {<ol} | {<caption} | {<output} | {<col} | {<p} | {<colgroup} | {<pre} | {<dd} | {<progress} | {<div} | 
	{<section} | {<dl} | {<table} | {<td} | {<dt} | {<tbody} | {<embed} | {<textarea} | {<fieldset} | {<tfoot} | {<figcaption} | 
	{<th} | {<figure} | {<thead} | {<footer} | {<tr} | {<form} | {<ul} | {<h1} | {<h2} | {<h3} | {<h4} | {<h5} | {<h6} | {<video} | 
	{<script} | {<style}
]
closing-tags: copy/deep tags
forall closing-tags [if string? closing-tags/1 [closing-tags/1: head insert next closing-tags/1 #"/"]]

html-comment: rule [] [
	"<!--" thru "-->"
]
html-instruction: rule [] [
	"<?" thru "?>"
]
html-cdata: rule [] [
	"<![CDATA[" thru "]]>"	
] 
html-tag: rule [] [
	tags | closing-tags
]

html-block: rule [value] [
	if (newline?)
	copy value [
		0 3 space
		[html-tag | html-comment | html-instruction | html-cdata]
		(debug-print ["==TAG:" value])
		to end-line
	]
	end-line
	(end-para/trim)
	(start-para?: false)
	(emit-line value)
	any [
		copy value [some not-newline to end-line] end-line
		(emit-line value)
	]
	end-line
	(start-para?: true)
]

tag-name: rule [] [
	letters
	any [letters | numbers]
]

tag-attributes: rule [mark] [
	any space
	attribute-name
	opt [
		any space
		#"="
		any space
		set mark [#"'" | #"^""]
		thru mark
	]
]

attribute-name: [some [letters | numbers | #":" | underscore]]

raw-html: rule [value ] [
;	copy value [#"<" tag-name any [tag-attributes | not [#">" | newline 0 3 space some [eq | minus]] skip] #">"]
	copy value [
		#"<" 
		tag-name 
		any tag-attributes
		any space
	;	any [
	;		tag-attributes 
	;	|	not [
	;			#">" 
	;		| 	newline 0 3 space some [eq | minus]
	;		] skip
	;	] 
		#">"
	]
;	copy value [#"<" some [tag-attributes | |not #">" skip] #">"]
	(debug-print ["==RAW TAG:" value])
	(start-para)
	(emit value)
]

char-rule: rule [value] [
	tab (
		newline?: false
		debug-print "::EMIT tab"
		emit "    "
	)
|	set value skip (
		newline?: false
		debug-print ["::EMIT character:" value]
		emit value
	)
]

para-char-rule: rule [value] [
	tab (
		newline?: false
		debug-print "::EMIT tab"
		emit "    "
	)
|	set value skip (
		newline?: false
		debug-print ["::EMIT[line] char" value]
		start-para
		emit value
	)
]

header-setext: rule [tag continue?] [
	; something about lazy continuation lines?
	if (all [lazy? newline? start-para?])
	; just check if the rule is fine
	(continue?: true)
	and [
		not code-prefix		; Setext header text lines must not be interpretable as block constructs other than paragraphs.
		some not-newline	; Setext headers cannot be empty
		newline
		0 3 space
		some [eq (tag: <h1>) | minus (tag: <h2>)]
		any space
		end-line
	]
	(debug-print ["==HEADER matched with" tag])
	(start-para?: false)
	(end-line?: false)
	; rule can be matched> | <generate output	
	(emit tag)
	0 3 space
	some [
		[
			any space
			newline
			thru end-line
			opt newline
			(continue?: false)
		]
	|	if (continue?) inline-rules
	|	if (continue?) space (emit space)
	]
	(
		emit-line close-tag tag
		end-para?: false
		start-para?: true
		end-line?: true
	)	
]

header-atx: rule [mark continue? space?] [
	(continue?: true)
	(space?: false)
	if (newline?)
	0 3 space 						; The opening # character may be indented 0-3 spaces.
	copy mark 1 6 hash 			; between an opening sequence of 1–6 unescaped # characters
	not hash 						; dtto
	and [whitespace | end] 		; The opening sequence of # characters cannot be followed directly by a non-space character.
	any space  (space?: true)			; dtto
	(
		start-para?: false
		if end-para? [
			; get rid of last newline before closing para
			remove-last-newline
			debug-print "::EMIT close-para (header-atx)"
			emit close-para
			emit-newline
		]
		emit tag: to tag! compose [h (length? mark)]
		debug-print ["==ATX: start" length? mark]
	)	

	some [
		[
			if (continue?)	
			[some space | if (space?)] 			; The optional closing sequence of #s must be preceded by a space
			some hash 			; optional closing sequence of any number of # characters
			and [any space newline]
			(debug-print "==ATX: closing seq")
		]
	|	[
			; ... may be followed by spaces only. 
			if (continue?)
			[any space | if (space?)] 
			newline 
			(
				debug-print "==ATX: end"
				emit-line close-tag tag 
				continue?: false
				start-para?: true
			)
			break
		]
	|	[if (continue?) (space?: false) inline-rules]
	|	[if (continue?) space (emit space)]
	]
	(debug-print "==ATX: endEND")
]

header-rule: [
	header-setext
|	header-atx
]

autolink-scheme: rule [] [
	"coap" | "doi" | "javascript" | "aaa" | "aaas" | "about" | "acap" | "cap" | "cid" | "crid" | "data" | "dav" | "dict" | "dns" | "file" | 
	"ftp" | "geo" | "go" | "gopher" | "h323" | "http" | "https" | "iax" | "icap" | "im" | "imap" | "info" | "ipp" | "iris" | "iris.beep" | 
	"iris.xpc" | "iris.xpcs" | "iris.lwz" | "ldap" | "mailto" | "mid" | "msrp" | "msrps" | "mtqp" | "mupdate" | "news" | "nfs" | "ni" | 
	"nih" | "nntp" | "opaquelocktoken" | "pop" | "pres" | "rtsp" | "service" | "session" | "shttp" | "sieve" | "sip" | "sips" | "sms" | 
	"snmp" | "soap.beep" | "soap.beeps" | "tag" | "tel" | "telnet" | "tftp" | "thismessage" | "tn3270" | "tip" | "tv" | "urn" | "vemmi" | 
	"ws" | "wss" | "xcon" | "xcon-userid" | "xmlrpc.beep" | "xmlrpc.beeps" | "xmpp" | "z39.50r" | "z39.50s" | "adiumxtra" | "afp" | 
	"afs" | "aim" | "apt" | "attachment" | "aw" | "beshare" | "bitcoin" | "bolo" | "callto" | "chrome" | "chrome-extension" | 
	"com-eventbrite-attendee" | "content" | "cvs" | "dlna-playsingle" | "dlna-playcontainer" | "dtn" | "dvb" | "ed2k" | "facetime" | 
	"feed" | "finger" | "fish" | "gg" | "git" | "gizmoproject" | "gtalk" | "hcp" | "icon" | "ipn" | "irc" | "irc6" | "ircs" | "itms" | "jar" | 
	"jms" | "keyparc" | "lastfm" | "ldaps" | "magnet" | "maps" | "market" | "message" | "mms" | "ms-help" | "msnim" | "mumble" | "mvn" | 
	"notes" | "oid" | "palm" | "paparazzi" | "platform" | "proxy" | "psyc" | "query" | "res" | "resource" | "rmi" | "rsync" | "rtmp" | 
	"secondlife" | "sftp" | "sgn" | "skype" | "smb" | "soldat" | "spotify" | "ssh" | "steam" | "svn" | "teamspeak" | "things" | "udp" | 
	"unreal" | "ut2004" | "ventrilo" | "view-source" | "webcal" | "wtai" | "wyciwyg" | "xfire" | "xri" | "ymsgr"
]

autolink-URI: rule [] [
	autolink-scheme
	#":"
	any [not [space | gt] skip]
]

autolink-rule: rule [scheme address] [
	lt
	(debug-print "==AUTOLINK start")
	; check if valid
	and [autolink-URI gt]
	; emit link start
	(
		debug-print ["==AUTOLINK RULE" address]
		start-para
		emit {<a href="}
	)
	; mark address start
	pos: 
	; emit address
	copy scheme autolink-scheme (emit scheme)
	#":" (emit #":")
	any [
		not [space | gt]
		[
			percent-encoding
		|	entities
		|	char-rule
		]
	]
	gt
	(emit {">})
	; rewind
	:pos 
	; copy adress again 
	copy scheme thru #":" (emit scheme)
	any [
		not [space | gt]
		[
			entities
		|	char-rule
		]
	]
	gt
	; done, close the link
	(
		debug-print ["==AUTOLINK RULE"]
		emit </a>
	)
]

link-rule: rule [text address value title] [
	#"["
	copy text
	to #"]" skip
	#"("
	(
		address: clear ""
		title: none
	)
	any [
		not [space | tab | #")"]
		set value skip
		(append address value)
	]
	opt [
		some [space | tab]
		#"^""
		copy title to #"^""
		skip
	]
	skip
	(
		start-para
		title: either title [ajoin [space {title="} title {"}]][""]
		emit ajoin [{<a href="} address {"} title {>} text </a>]
	)
]

em-rule: rule [mark text content] [
	copy mark ["*" | "_"]
	(content: complement charset reduce [newline mark])
	(debug-print ["==EM rule matched with" mark])
	not space
	(debug-print "==EM rule> | <no space")
	and [some content mark]
	(start-para)
	(emit <em>)
	(start-para?: false)
	(debug-print ["==EM rule started"])
	some [
		mark break
	|	inline-code-rule	
	|	char-rule	
	]
	(
		debug-print ["==EM rule ended"]
		emit </em>
	)
]

strong-rule: rule [mark text content pos] [
	copy mark ["**" | "__"]
	(content: complement charset reduce [newline first mark])
	(debug-print ["==STRONG rule start matched with" mark])
	not space
	and [some content mark]
	(start-para)
	(emit <strong>)
	(start-para?: false)
	(debug-print ["==STRONG rule started"])
	some [
		mark break
	|	inline-code-rule	
	|	char-rule	
	]
	(
		debug-print ["==STRONG rule ended"]
		emit </strong>
	)
]


img-rule: rule [text address] [
	#"!"
	#"["
	copy text
	to #"]" skip
	#"("
	copy address
	to #")" skip
	(
		start-para
		emit ajoin [{<img src="} address {" alt="} text {"} either xml? { /} {} {>}]
	)
]

; TODO: make it bitset!
horizontal-mark: [minus | asterisk | underscore]

match-horizontal: [
	if (newline?)
	0 3 space
	set mark horizontal-mark
	any space
	mark
	any space
	mark
	(debug-print "==HORIZONTAL rule matched")
	any [
		mark
	|	space
	]
	newline
]

horizontal-rule: rule [mark] [
	match-horizontal
	(
		end-para/trim
		if end-line? [emit-newline]
		(debug-print "::EMIT horizontal rule")
		start-para?: false
		emit either xml? <hr /><hr>
		emit-newline
		start-para?: true
	)
]

unordered: [any space [asterisk | plus | minus] space]
ordered: [any space some numbers dot space]

; TODO: recursion for lists

list-rule: rule [continue? tag item] [
	if (newline?)
	[
		ordered (item: ordered tag: <ol>)
	|	unordered (item: unordered tag: <ul>)
	]
	(continue?: true)
	(lazy?: false)
	(debug-print ["==LIST rule start:" tag])
	(start-para?: end-para?: false)
	(emit-line tag)
	(emit <li>)
	(end-line?: true)
	(debug-print ["==LIST item #1"])
	(newline?: true)
	some line-rules
	(debug-print ["??start-para?" start-para?])
	end-line
	(emit-line </li>)
	(debug-print ["==LIST item #1 end"])
	any [
		and match-horizontal	
	|	[
			item
			(emit <li>)
			(end-line?: true)
			(newline?: true)
			(debug-print ["==LIST item"])
			some line-rules
			end-line
			(start-para?: false)
			(emit-line </li>)
			(debug-print ["==LIST item end"])
		]
	]
	(lazy?: true)
	(emit-line close-tag tag)
	(debug-print ["==LIST rule end:" tag])
]

blockquote-prefix: [gt any space]

blockquote-rule: rule [continue] [
	if (newline?)
	blockquote-prefix
	(start-para?: false)
	(emit-line <blockquote>)
	(debug-print "==BLOCKQUOTE line 1")
	(start-para?: true)
	(lazy?: false)
	line-rules
	(debug-print "==BLOCKQUOTE line rules")
	end-line (emit-newline)
	any [
		; FIXME: what an ugly hack
		[newline ] (
			debug-print "::EMIT close-para (blockquote #1)"
			remove back tail md-buffer 
			emit ajoin [close-para newline newline open-para]
		)
	|	[
			blockquote-prefix
			(debug-print "==BLOCKQUOTE line")
			opt line-rules
			end-line (emit-newline)
;			[newline (emit-newline) | end]
		]
	]
	(end-para?: false)
	(lazy?: true)
	(debug-print "::EMIT close-para (blockquote #2)")
	(remove-last-newline)
	(emit ajoin [close-para newline </blockquote>])
	(emit-newline)
]

inline-code-rule: rule [code value] [
	[
		"``" 
		(start-para)
		(emit <code>)
		(debug-print "==INLINE-CODE")
		any space
		some [
			any space "``" (emit </code>) break ; end rule
		|	entity-descriptors	
		|	entities
		|	char-rule
		]
	]
|	[
		and ["`" to "`"]
		"`"
;		(start-para)
;		(end-para?: false)
		(emit <code>)
		some [
			"`" (emit </code>) break ; end rule
		|	entity-descriptors	
		|	entities
		|	char-rule
		]
	]
]

code-line-old: rule [value length] [
	some [
		entity-descriptors	
	|	entities
	|	if (newline?) newline (debug-print "==NEWLINE in CODE to be skipped") break
	|	end-line (emit-newline) break
	|	tab (
			debug-print ["found tab:" line-index "," 4 - (line-index // 4)] 
			length: 4 - (line-index // 4)
			emit rejoin array/initial length space
		)
	|	char-rule
	]
]

code-line: rule [length] [
	some [
		code-entity-rule
	|	tab (
			debug-print ["found tab:" line-index "," 4 - (line-index // 4)] 
			length: 4 - (line-index // 4)
			emit rejoin array/initial length space
		)
	|	not end-line char-rule
	]
]

code-prefix: [[4 space | tab] (debug-print "==CODE: 4x space or tab matched")]

code-rule: rule [pos text] [
	if (all [newline? start-para?])
	(debug-print "==CODE rule can run")
	any newline
	code-prefix
	(start-para?: false)
	(emit ajoin [<pre><code>] newline?: true)
	[code-line | newline]
	(debug-print "==CODE first line done")
	any [
		code-prefix
		code-line
	|	any space newline (emit-newline)	
	]
	; remove trailing newlines (not a best solution...)
	(
		while [equal? newline last md-buffer] [take/last md-buffer]
		emit-newline
	)
	; ---
	(emit ajoin [</code></pre>])
	(emit-newline)
	(start-para?: true)
	(end-para?: false)
]

fenced-code-rule: rule [indent mark count] [
	if (all [newline? start-para?])
	(debug-print "==CODE rule can run")
	(indent: clear "")
	copy indent any space
	(debug-print ["==FENCED CODE indent length" length? indent])
	copy mark [
		set mark-char ["```" | "~~~"]
		any mark-char
	]
	(start-para?: false)
	opt [some space]
	(emit ajoin [<pre><code>] newline?: true)
	pos:
	(debug-print ["==FENCED CODE rule matched" mark mold pos])
	any [
		pos: ([debug-print "xx" mold pos ]) opt indent [
			(debug-print "xx1") any space newline any space newline (emit-newline)
		|	(debug-print "xx2") not [mark | end] (debug-print "xx3") opt indent code-line newline (emit-newline)
		|	any space newline
		]
	]
	(debug-print "xx4")
	opt indent [
		end (debug-print "==FENCED CODE: END matched") 
	|	mark any mark-char (debug-print "==FENCED CODE: MARK matched") 
	]
	(debug-print "xx5")
	; remove trailing newlines (not a best solution...)
	(
		count: 0
		while [equal? newline last md-buffer] [take/last md-buffer ++ count]
		if count > 0 [emit-newline]
	)
	; ---	
	(debug-print "==FENCED CODE rule ended")
	(emit ajoin [</code></pre>])
	(emit-newline)
	(end-para?: false)
]

newline-rule: [
	newline 
	any [space | tab] 
	some newline 
	any [space | tab]
	(
		debug-print "::END-PARA in newline-rule"
		end-para
	)
|	[newline end | end] 
	(end-para)	
|	newline (
		debug-print ["==NEWLINE only" newline?]
		unless newline? [emit-newline]
	)
]

line-break-rule: [
	space
	some space
	newline
	(emit ajoin [either xml? <br /> <br>])
	(emit-newline)
]

leading-spaces: rule [] [
	if (newline?)
	[some space]
	(debug-print "==LEADING SPACES")
	(start-para)
	(newline?: false)
]

; simplified rules used as sub-rule in some rules

line-rules: [
	header-rule
|	horizontal-rule
|	em-rule
|	strong-rule
|	link-rule
|	entity-rule
|	not newline para-char-rule
]

inline-rules: [
	em-rule
|	strong-rule
|	entity-rule
|	not [newline | space] char-rule
]

; TODO: simplify and make it work

strong-content: [
	em-rule
|	entity-rule
|	not [newline | space | "**" | "__"] char-rule
]

em-content: [
	strong-rule
|	entity-rule
|	not [newline | space | "*" | "_"] char-rule
]

; main rules

rules: [
;	any space
	some [	
		html-block
	|	raw-html	
	|	img-rule
	|	horizontal-rule
	|	list-rule
	|	blockquote-rule
	|	header-rule
	|	fenced-code-rule
	|	inline-code-rule
	|	code-rule	
	|	autolink-rule
	|	entity-rule
	|	em-rule
	|	strong-rule
	|	link-rule
	|	line-break-rule
	|	newline-rule
	|	leading-spaces
	|	para-char-rule
	]
]

markdown: func [
	"Parse markdown source to HTML or XHTML"
	data
	; TODO:
	/only "Return result without newlines"
	; TODO:
	/xml "Switch from HTML tags to XML tags (e.g.: <hr /> instead of <hr>)"
	/snippet "Do not emit opening <p>"
	/debug "Turn on debugging"
] [
	start-para?: true
	end-para?: false
	end-line?: false
	newline?: true
	lazy?: true
	set [open-para close-para] either snippet [["" ""]] [[<p></p>]]
	debug?: debug
	clear head md-buffer
	debug-print "** Markdown started"
	parse data rules
	md-buffer
]
