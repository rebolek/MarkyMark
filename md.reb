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
	Notes: ["For mardown specification, see http://johnmacfarlane.net/babelmark2/faq.html"]
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

emit: func [data] [
;	print "***wrong emit***" 
	newline?: false
	append md-buffer data
]

emit-newline: does [
	debug-print "::EMIT newline"
	append md-buffer newline
	newline?: true
	end-line?: false
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
		emit open-para
	]
]

entities: [
	#"<" (emit "&lt;")
|	#">" (emit "&gt;")
|	#"&" (emit "&amp;")
|	#"^"" (emit "&quot;")
]
escape-set: charset "\`*_{}[]()#+-.!"
escapes: rule [escape] [
	#"\"
	(start-para)
	set escape escape-set
	(emit escape)
]
numbers: charset [#"0" - #"9"]
not-newline: complement charset newline
; some "longer, but readable" stuff
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

header-setext: rule [tag continue?] [
	; something about lazy continuation lines?
	if (lazy?)
	; just check if the rule is fine
	(continue?: true)
	and [
		thru newline 			; NOTE: is this enough?
		0 3 space
		some [eq (tag: <h1>) | minus (tag: <h2>)]
		any space
		[newline | end]
	]
	; rule can be matched, generate output
	(start-para?: false)
	(emit tag)
	0 3 space
	some [
		[
			any space
			newline
			thru [newline | end]
			opt newline
			(continue?: false)
		]	
	|	if (continue?) inline-rules
	|	if (continue?) space (emit space)
	]
	(
		debug-print ["==HEADER matched with" tag]
		debug-print "__START PARA"
		end-para?: false
		start-para?: true
		emit close-tag tag
		emit-newline
	)	
]

header-underscore: rule [text tag] [
	copy text to newline 
	newline
	some [eq (tag: <h1>) | minus (tag: <h2>)]
	[newline | end]
	(
		debug-print ["==HEADER matched with" tag]
		debug-print "__START PARA"
		end-para?: false
		start-para?: true
		emit ajoin [tag text close-tag tag]
		emit-newline
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
			pos:
			[any space (debug-print "%%__") | if (space?)] 
			pos:
			newline 
			pos: (
				end-para?: false
				start-para?: true
				debug-print "==ATX: end"
				print mold pos
				emit close-tag tag 
				emit-newline
				continue?: false
			)
			break
		]
	|	[if (continue?) (space?: false) inline-rules]
	|	[if (continue?) space (emit space)]
	]
]

header-rule: [
;	header-underscore
	header-setext
|	header-atx
]

autolink-rule: rule [address] [
	lt
	copy address ; TODO: Parse address to match email
	to gt skip
	(
		debug-print "==AUTOLINK RULE"
		start-para
		emit ajoin [{<a href="} address {">} address </a>]
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
	(debug-print "==EM rule, no space")
	and [some content mark]
	(debug-print "==EM rule, found end")
	copy text
	to mark mark
	(
		debug-print ["==EM rule matched"]
		start-para
		mark: <em>
		emit ajoin [mark text close-tag mark]
	)
]

strong-rule: rule [mark text content pos] [
	copy mark ["**" | "__"]
	(content: complement charset reduce [newline first mark])
	(debug-print ["==STRONG rule start matched with" mark])
	not space
	and [some content mark]
	copy text
	to mark mark
	(
		debug-print ["==STRONG rule matched"]
		start-para
		mark: <strong>
		emit ajoin [mark text close-tag mark]
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
	(debug-print ["??newline" newline?])
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
		if end-para? [
			; get rid of last newline before closing para
			remove-last-newline
			debug-print "::EMIT close-para (header-setext)"
			emit close-para
			emit-newline
		]
		if end-line? [emit-newline]
		start-para?: true
		end-para?: false
		emit either xml? <hr /><hr>
		emit-newline
	)
]

unordered: [any space [asterisk | plus | minus] space]
ordered: [any space some numbers dot space]

; TODO: recursion for lists

list-rule: rule [continue? tag item] [
	some [
		if (start-para?)
		[
			ordered (item: ordered tag: <ol>)
		|	unordered (item: unordered tag: <ul>)
		]
		(continue?: true)
		(lazy?: false)
		(debug-print ["==LIST rule start:" tag])
		(start-para?: end-para?: false)
		(emit tag)
		(emit-newline) 
		(emit <li>)
		(end-line?: true)
		(debug-print ["==LIST item #1"])
		(newline?: true)
		line-rules
		newline
		(emit </li>)
		(emit-newline)
		(debug-print ["==LIST item #1 end"])
		any [
			and match-horizontal
		|	[
				item
				(emit <li>)
				(end-line?: true)
				(newline?: true)
				(debug-print ["==LIST item"])
				line-rules
				[newline | end]
				(emit </li>)
				(emit-newline)
				(debug-print ["==LIST item end"])
			]
		]
		(lazy?: true)
		(emit close-tag tag emit-newline)
		(debug-print ["==LIST rule end:" tag])
	]
]

blockquote-prefix: [gt any space]

blockquote-rule: rule [continue] [
	if (start-para?)
	blockquote-prefix
	(emit ajoin [<blockquote> newline])
	(lazy?: false)
	line-rules
	[[newline (emit-newline)] | end]
	any [
		; FIXME: what an ugly hack
		[newline ] (
			debug-print "::EMIT close-para (blockquote #1)"
			remove back tail md-buffer 
			emit ajoin [close-para newline newline open-para]
		)
	|	[
			blockquote-prefix
			opt line-rules
			[newline (emit-newline) | end]
		]
	]
	(end-para?: false)
	(lazy?: true)
	(debug-print "::EMIT close-para (blockquote #2)")
	(if equal? newline last md-buffer [remove back tail md-buffer])
	(emit ajoin [close-para newline </blockquote>])
	(emit-newline)
]

inline-code-rule: rule [code value] [
	[
		"``" 
		(start-para)
		(emit <code>)
		(debug-print "==INLINE-CODE")
		some [
			"``" (emit </code>) break ; end rule
		|	entities
		|	set value skip (emit value)
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
		|	entities
		|	set value skip (emit value)
		]
	]
]

code-line: rule [value length] [
	some [
		entities
	|	[newline | end] (emit-newline) break
	|	tab (
			debug-print ["found tab:" line-index "," 4 - (line-index // 4)] 
			length: 4 - (line-index // 4)
			emit rejoin array/initial length space
		)
	|	set value skip (emit value)	
	]
]

code-prefix: [4 space | tab]

code-rule: rule [pos text] [
	pos:
	if (any [head? pos equal? "^/^/" back back pos])
	code-prefix
	(
		debug-print "==CODE: 4x space or tab matched"
		emit ajoin [<pre><code>]
	)
	code-line
	any [
		code-prefix
		code-line
	|	newline (emit-newline)	
	]
	(emit ajoin [</code></pre>])
	(emit-newline)
	(end-para?: false)
]

asterisk-rule: ["\*" (emit "*")]

hash-rule: ["\#" (emit "#")]

newline-rule: [
	newline 
	any [space | tab] 
	some newline 
	any [space | tab]
	(
		debug-print "==EMIT close-para (newline)"	

		emit close-para 
		emit-newline
		start-para?: true
		debug-print "__START PARA"
	)
|	newline (
		debug-print "==NEWLINE only"
		emit-newline
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
	some [
		header-rule
	|	horizontal-rule
	|	em-rule
	|	strong-rule
	|	link-rule
	|	asterisk-rule
	|	not newline set value skip (
		newline?: false
		debug-print ["::EMIT[line] char" value]		
		start-para
		emit value
	)
	]
]

inline-rules: [
	em-rule
|	strong-rule
|	asterisk-rule
|	hash-rule
|	entities
|	not [newline | space] set value skip (
		newline?: false
		debug-print ["::EMIT[inline] char" value]	
		emit value
	)
]

; other set of sub-rules

sub-rules: [
	code-rule
]

; main rules

rules: [
;	any space
	some [	
		
		img-rule
	|	horizontal-rule
	|	list-rule
	|	blockquote-rule
	|	header-rule
	|	inline-code-rule
	|	code-rule
	|	asterisk-rule
	|	em-rule
	|	strong-rule
	|	autolink-rule
	|	link-rule
	|	entities
	|	escapes
	|	line-break-rule
	|	[newline end | end] (if end-para? [debug-print "::EMIT close-para (rules/newline)" end-para?: false emit ajoin [close-para newline]])
	|	newline-rule	
	|	leading-spaces
	|	set value skip (
			newline?: false
			debug-print ["::EMIT char" value]
			start-para
			emit value
		)	
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
