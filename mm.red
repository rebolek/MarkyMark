Red[]

string: ""

output: []
target: output
stack: []

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
thematic-break: [
	0 3 space
	[
		set thematic-mark [#"*" | #"-" | #"_"]
		2 [any space thematic-mark]
		any [any space thematic-mark]
		any space
	]
	newline
	(append target 'hr)
]

; -- indent-code --

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
|	strong-content
|	em-content
|	line-content
;|	set value skip (append string value)
]

line-content: [
	ws*
	some [
		newline (append string newline) break
	|	set value skip (append string value)
	]
]

; -- main --

main-rule: [
	some [
		blank-line
	|	thematic-break
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
	para: [
		'para (append out <p>)
		ahead block! into rule
		; NEWLINE goes after </p>
		(take/last out)
		(append out </p>)
		(append out newline)
	]
	rule: [
		some [
			'em (append out <em>) ahead block! into rule (append out </em>)
		|	'strong (append out <strong>) ahead block! into rule (probe append out </strong>)
		|	'hr	(append out "<hr />^/")
		|	para
		|	set value string! (probe append out value)
		|	ahead block! into rule
		]
	]
	parse data [
		rule
	]
	out
]

markdown: func [value][hm md value]
