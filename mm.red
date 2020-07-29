Red[
	Bugs: [
		#89 {
			`parse " " [0 0 space]` returns TRUE, I believe it's a bug
		}
	]
	To-Do: {
		CLASS stuff in HM should be universal (needs support in EMIT)
		and also should be on same level as tag:
			currently: [tag [#class content]]
			preffered: [tag #class [content]]
	}
]

string: ""

output: []
target: output
stack: []
stop?: false ; NOTE: set this to TRUE to not include newline after inline text
code?: false

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

; -- entities --

html-entities: load %entities
named-entities: copy html-entities

entity-list: collect [
	foreach [entity _] html-entities [keep reduce [entity '|]]
]
take/last named-entities

entity: none
named-entities: [
	#"&"
	copy entity entity-list
	#";"
;	(keep to char! to integer! to issue! select/case html-entities entity)
	(
		value: select/case html-entities entity
		foreach _ value [keep to char! _]
	)
]

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
amp: #"&"
semicolon: #";"
hash: #"#"
digit: charset "1234567890"
hex-digit: charset "1234567890abcdefABCDEF"
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
keep-as-entities: [
	"&amp;" (keep "&amp;")
]

#TODO "converted chars must be checked agains entities list (e.g. & -> &amp;)"
number: none
decimal-entities: [
	amp hash copy number 1 7 digit semicolon
	(number: to integer! number)
]
hexadecimal-entities: [
	amp hash [#"x" | #"X"] copy number 1 6 hex-digit semicolon
	(number: to integer! to issue! number)
]
numeric-entities: [
	[decimal-entities | hexadecimal-entities]
	(
		if zero? number [number: 65533] ; NOTE: REPLACEMENT CHARACTER (#312)
		keep to char! number
	)
]

text-content: [
	keep-as-entities
|	if (not code?) named-entities
|	if (not code?) numeric-entities
|	entities
|	if (code?) not newline set value skip (keep value) ; TODO: Optimize, it same as last line
|	#"\" entities
|	[#"\" | 2 space any space] line-ending ahead not end any space (emit emit-value 'br)
|	#"\" set value ascii-punctuation-char (keep value)
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
indented-code-start: [ahead [4 space | 0 3 space tab]]
indented-code-line: [
	[4 space | 0 3 space tab] 
	some [
		newline (keep newline) break
	|	entities
	|	set value skip (keep value)
	]
	(emit)
]
indented-code-block: [
	indented-code-start
	(push 'pre push 'code)
	some indented-code-line
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
	any space
	(push 'code)
	(code?: true)
	some [
		any space code-span-mark break
	|	newline (keep space) ; convert to space
	|	text-content
	]
	(code?: false)
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
	; TODO: entities in fenced-code-lang must be translated (&ouml; -> ö) #320
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
	(code?: true)
	(push 'pre)
	(push 'code)
	(unless empty? fenced-code-lang [emit-value to issue! fenced-code-lang])
	any [
		[fenced-code-mark thru newline | end] break
	|	0 fenced-code-indent space
		fenced-code-line
	]
	(code?: false)
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

	parse/case input main-rule
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
		set tag ['em | 'strong | 'pre | 'h1 | 'h2 | 'h3 | 'h4 | 'h5 | 'h6]
		(append out to tag! tag)
		(append tag-stack tag)
		ahead block! into rule
		(tag: take/last tag-stack)
		(append out to tag! to refinement! tag)
	]
	class: none
	code-rule: [
		'code
		(class: none)
		(append out {<code})
		(append tag-stack 'code)
		into [
			opt [
				set class issue!
				(append out rejoin [{ class=language-"} form class {"}])]
			(append out ">")
			rule
		]
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
		|	code-rule
		|	link-rule
		|	'hr	(append out "<hr />^/")
		|	'br	(append out "<br />^/")
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
