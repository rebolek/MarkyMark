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
stop?: false ; NOTE: set this to TRUE to not include newline after inline text

push: func [rule [word!]][
	unless empty? string [emit]
	repend target [rule copy []]
	append/only stack tail target
	target: last target
]
pop: func [][target: take/last stack]
emit-pop: func ["Emit content and pop from stack"][
	emit
	pop
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

; definitions from specs

; support

to-char: func [value][to char! to integer! value]
chset: func [value][charset collect [foreach char value [keep to-char char]]]

crlf-set: charset reduce [cr lf]
sptb-set: charset reduce [space tab]

; actual defs

character: [skip]
line: [any [not crlf-set skip] line-ending]
line-ending: [crlf-set not crlf-set]
blank-line: [any sptb-set line-ending]
whitespace-char: chset [#20 #09 #0A #0B #0C #0D]
whitespace: [some whitespace-char]
; unicode-whitespace
; space - already defined in Red
non-whitespace-char: complement whitespace-char
ascii-punctuation-char: make bitset! #{000000007FFF003F8000001F8000001E} ; see %scraper.red how to get this [grab 'punct]
; punctuation-char - TODO: see Unicode categories Pc, Pd, Pe, Pf, Pi, Po and Ps


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
;|	#"\" 		(keep #"\")
]

text-content: [
	entities
|	#"\" entities
|	#"\" set value skip (keep value)
|	not newline set value skip (keep value)
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
	(emit-newline)
	(stop?: false)
]

; -- setext heading --

setext-type: none
setext-heading-start: [
	ahead [
		thru newline ;at least one line precedes underlining
		thru [
			0 3 space
			copy setext-type [some #"=" | some #"-"]
		]
		(setext-type: select [#"=" h1 #"-" h2] first setext-type)
		any space
		newline
	]
]
setext-heading: [
	setext-heading-start
	(push setext-type)
	(stop?: true)
	some [
		newline break
	|	inline-content
	]
	thru newline
	(emit-pop)
	(emit-newline)
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

; -- indented code block --

code-line: none
indented-code-line: [[4 space | 0 3 space tab] copy code-line thru newline]
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
		[fenced-code-mark thru newline | end] break
	|	0 fenced-code-indent space
		fenced-code-line
	]
	(emit-pop)
	(emit-pop)
	(emit-newline)
]

; -- links --

link-text:
link-destination:
link-title: none

inline-link-start: [
	#"["
	ahead [to [#"]" #"("]]
]
inline-link-content: [
	inline-link-start
	copy link-text to #"]" skip
	#"(" copy link-target to [space | #")"]
	(link-title: none)
	opt [
		space
		copy link-title to #")"
	]
	#")"
	(push 'a)
	(emit-value to url! link-target)
	(if link-title [emit-value 'title emit-value link-title])
	(emit-value link-text)
	(pop)
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
|	ahead fenced-code-start break
|	code-span-content
|	strong-content
|	em-content
|	inline-link-content
|	line-content
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
	|	setext-heading
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
	stop?: false

	parse input main-rule
	emit
	output
]


; -- lest -------------------------------------------------------------------

hm: func [
	data [block!]
	/local out rule para value target
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
		set tag ['em | 'strong | 'code | 'pre | 'h1 | 'h2 | 'h3 | 'h4 | 'h5 | 'h6]
		(append out to tag! tag)
		(append tag-stack tag)
		ahead block! into rule
		(tag: take/last tag-stack)
		(append out to tag! to refinement! tag)
	]
	link-rule: [
		'a
		into [
			set target url!
			(append out rejoin [{<a href="} target {"}])
			opt [
				'title
				set value string!
				(append out rejoin [{ title=} value])
			]
			(append out #">")
			some [
				tag-rule
			|	set value [string! | char!] (append out value)
			]
			(append out </a>)
		]
	]
	rule: [
		any [
			tag-rule
		|	link-rule
		|	'hr	(append out "<hr />^/")
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
