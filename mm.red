Red[
	Bugs: [
		#89 {
			`parse " " [0 0 space]` returns TRUE, I believe it's a bug
		}
	]
]

string: ""

output: []
target: output
stack: []
stop?: false

push: func [rule [word!]][
	unless empty? string [emit]
	repend target [rule copy []]
	append/only stack tail target
	target: last target
]
emit-pop: func ["Emit content and pop from stack"][
	emit string 
	target: take/last stack
]
emit: func [][
	if empty? string [exit]
	append target copy string
	clear string
]
emit-value: func [value][append target value]
emit-newline: func [][append target newline]

keep: func [value][append string value]

; ---------------------------------------------------------------------------
backtick: #"`"
tilde: #"~"
backslash: #"\"
ws: charset " ^-" ; NOTE: newline has special meaning
ws*: [any ws]
ws+: [some ws]
blank-line: [go-back newline ws* newline]

entities: [
	#"<" 		(keep "&lt;")
|	#">" 		(keep "&gt;")
|	#"&" 		(keep "&amp;")
|	#"^"" 		(keep "&quot;")
|	#"\" 		(keep #"\")
]

text-content: [
	entities
|	set value skip (keep value)
]

mark: none
go-back: [mark: (mark: back mark) :mark]

; -- emphasis --

em-mark: none
em-start: [
	copy em-mark [#"*" | #"_"]
	not space ; TODO: not whitespace
	not ahead to code-span-start
	ahead to em-end
]
em-end: [
	not [em-mark em-mark not em-mark] ; not a start/end of STRONG, but end of STRONG+end of EM is possible
	em-mark
	2 go-back ; move before mark and check what's there
	not [em-mark | backslash | space]
	2 skip
]
em-content: [
	em-start
	(push 'em)
	some [
		em-end (emit-pop) break
	|	ahead strong-start (emit) strong-content
	|	text-content
	]
] 

; -- strong --

strong-mark: none
strong-start: [
	copy strong-mark ["**" | "__"] 
	not space
	not ahead code-span-start
	ahead to strong-end
]
strong-end: [
	strong-mark
	3 go-back
	not [backslash | space]
	3 skip
]
strong-content: [
	strong-start
	(push 'strong)
	some [
		strong-end (emit-pop) break
	|	ahead em-start (emit) em-content
	|	text-content
	]
]

; -- thematic break --

thematic-mark: none
thematic-start: [
	0 3 space
	[
		set thematic-mark [#"*" | #"-" | #"_"]
		2 [any space thematic-mark]
		any [any space thematic-mark]
		any space
	]
	newline
]
thematic-break: [
	thematic-start
	(append target 'hr)
]

; -- ATX heading --

atx-mark: none
atx-heading: [
	copy atx-mark 1 6 #"#" space
	(stop?: true)
	(push to word! rejoin ['h length? atx-mark])
	inline-content
	(emit-pop)
	(stop?: false)
]

; -- setext heading

; TODO

; -- block quote --


block-quote-marker: [
	0 3 space
	#">"
	any space
]
block-quote: [
	block-quote-marker
	(push 'blockquote)
; TODO
]

; -- indented code block --

code-line: none
indented-code-line: [4 space copy code-line thru newline]
indented-code-block: [
	indented-code-line
	(push 'pre push 'code)
	(emit-value code-line)
	any [
		indented-code-line
		(emit-value code-line)
	]
	(emit-pop)
	(emit-pop)
	(emit-newline)
]

; -- inline code --

code-span-mark: none
code-span-start: [
	copy code-span-mark some #"`"
	ahead to code-span-mark
]
code-span-content: [
	code-span-start
	(push 'code)
	some [
		code-span-mark break
	|	newline ; ignore
	|	text-content
	]
	(emit-pop)
]

; -- fenced code --
fenced-code-indent:
fenced-code-lang:
fenced-code-mark:
fenced-code-line: none
fenced-code-start: [
	copy fenced-code-indent 0 3 space
	(fenced-code-indent: length? fenced-code-indent)
	copy fenced-code-mark [
		3 backtick any backtick
	|	3 tilde any tilde
	]
	any space
	copy fenced-code-lang to [space | newline]
	thru newline
	ahead to [fenced-code-mark | end]
]
fenced-code-line: [
	some [
		newline break
	|	text-content
	]
	(emit)
	(emit-newline)
]
fenced-code: [
	fenced-code-start
	(push 'pre)
	(push 'code)
	any [
		[fenced-code-mark thru newline | (print "check end") end] break
	|	0 fenced-code-indent space
		fenced-code-line
	]
	(emit-pop)
	(emit-pop)
	(emit-newline)
]

; -- para --

para: [
	not blank-line
	(push 'para)
	ws*
	some inline-content
	(emit-pop)
]

; -- inline --

inline-content: [
	blank-line break
|	ahead thematic-start break
|	code-span-content
|	strong-content
|	em-content
|	line-content
;|	set value skip (append string value)
]

line-content: [
	ws*
	some [
		newline (unless stop? [append string newline]) break
	|	ahead [code-span-start | strong-start | em-start] break
	|	text-content
	]
]

; -- main --

main-rule: [
	some [
		blank-line
	|	thematic-break
	|	atx-heading
	|	indented-code-block
	|	fenced-code
	|	para
	]
]

md: func [input [string!]][
	string: clear ""
	output: clear []
	target: output
	stack: clear []

	parse input main-rule
	emit
	output
]


; -- lest -------------------------------------------------------------------

hm: func [
	data [block!]
	/local out rule para value
][
	out: clear ""
	tag-stack: clear []
	para: [
		'para (append out <p>)
		ahead block! into rule
		; NEWLINE goes after </p>
		(take/last out)
		(append out </p>)
		(append out newline)
	]
	tag-rule: [
		set tag ['em | 'strong | 'code | 'pre]
		(append out to tag! tag)
		(append tag-stack tag)
		ahead block! into rule
		(tag: take/last tag-stack)
		(append out to tag! to refinement! tag)
	]

	rule: [
		any [
			tag-rule
		|	'hr	(append out "<hr />^/")
		|	set tag ['h1 | 'h2 | 'h3 | 'h4 | 'h5 | 'h6] (append out to tag! tag) ahead block! into rule (append out to tag! to refinement! tag append out newline)
		|	para
		|	set value [string! | char!] (append out value)
		|	ahead block! into rule
		]
	]
	parse data [
		rule
	]
	out
]

markdown: func [value][hm md value]
