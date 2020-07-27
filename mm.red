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

backslash: #"\"

mark: none
go-back: [mark: (mark: back mark) :mark]

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

main-rule: [
	some [
		strong-content
	|	em-content
	|	set value skip (append string value)
	]
]

md: func [value [string!]][
	string: clear ""
	output: clear []
	target: output
	stack: clear []

	parse value main-rule
	emit
	output
]

hm: func [
	data [block!]
;	/local out rule
][
	out: clear ""
	rule: [
		some [
			'em (append out <em>) rule (append out </em>)
		|	'strong (append out <strong>) rule (append out </strong>)
		|	set value string! (append out value)
		|	ahead block! into rule
		]
	]
	parse data [
		(append out <p>)
		rule
		(append out </p>)
		(append out newline)
	]
	out
]
