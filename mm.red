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

emph-mark: none
emph-start: [
	copy emph-mark [#"*" | #"_"]
	not space ; TODO: not whitespace
	ahead to emph-end
]
emph-end: [
	not [emph-mark emph-mark not emph-mark] ; not a start/end of STRONG, but end of STRONG+end of EMPH is possible
	emph-mark
	2 go-back ; move before mark and check what's there
	not [emph-mark | backslash | space]
	2 skip
]
emph-content: [
	emph-start 
	(push 'emph)
	some [
		emph-end (emit-pop) break
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
	|	ahead emph-start (emit) emph-content
	|	set value skip (append string value)
	]
]

main-rule: [
	some [
		strong-content
	|	emph-content
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
