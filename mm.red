Red[]

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

; ---------------------------------------------------------------------------

backslash: #"\"
ws: charset " ^-" ; NOTE: newline has special meaning
ws*: [any ws]
ws+: [some ws]
blank-line: [go-back newline ws* newline]

mark: none
go-back: [mark: (mark: back mark) :mark]

; -- emphasis --

em-mark: none
em-start: [
	copy em-mark [#"*" | #"_"]
	not space ; TODO: not whitespace
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
	|	set value skip (append string value)
	]
] 

; -- strong --

strong-mark: none
strong-start: [
	copy strong-mark ["**" | "__"] 
	not space
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
	|	set value skip (append string value)
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
	|	set value skip (append string value)
	]
	(emit-pop)
]

; -- indent code --

#TODO ""

code-mark: none
code-content: []
indent-code: [
	copy code mark [any space tab] (push 'pre push 'code)
	some [
		newline (append string newline)
	|	
	]
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
	|	set value skip (append string value)
	]
]

; -- main --

main-rule: [
	some [
		blank-line
	|	thematic-break
	|	atx-heading
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
		set tag ['em | 'strong | 'code]
		(append out to tag! tag)
		(append tag-stack tag)
		ahead block! into rule
		(tag: take/last tag-stack)
		(append out to tag! to refinement! tag)
	]
	

	rule: [
		some [
			tag-rule
		|	'hr	(append out "<hr />^/")
		|	set tag ['h1 | 'h2 | 'h3 | 'h4 | 'h5 | 'h6] (append out to tag! tag) ahead block! into rule (append out to tag! to refinement! tag append out newline)
		|	para
		|	set value string! (append out value)
		|	ahead block! into rule
		]
	]
	parse data [
		rule
	]
	out
]

markdown: func [value][hm md value]
