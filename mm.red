Red[]

string: ""

output: []
target: output
stack: []

push: func [rule [word!]][
	repend target [rule copy []]
	append/only stack tail target
	target: last target
]
emit-pop: func ["Emit content and pop from stack" value [string!]][
	emit value
	target: take/last stack
]
emit: func [value [string!]][
	append target copy value
	clear value
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
	not [emph-mark emph-mark] ; not a start of STRONG
	emph-mark
	2 go-back ; move before mark and check what's there
	not [emph-mark | backslash | space]
	2 skip
]
emph-content: [
	emph-start 
	(push 'emph)
	some [
		emph-end (emit-pop string) break
	|	ahead strong-start (emit string) strong-content
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
		strong-end (emit-pop string) break
	|	set value skip (append string value)
	]
]
