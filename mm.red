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

#include %lest.red

!?: false
;!?: true
!!: func [value][if !? [print mold value]]


string: ""

output: []
target: output
stack: []
mark: none
stop?: false ; NOTE: set this to TRUE to not include newline after inline text
code?: false
full-trim?: false ; remove all leading/trailing whitespace from string

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

trim-string: func [][
	if full-trim? [full-trim?: false return trim string]
	if space = string/1 [take string]
	if all [
		space = last string
		space <> first skip tail string -2
	][take/last string]
	trim/tail string
	unless stop? [keep newline]
]

; ---------------------------------------------------------------------------

; parse probe

pp: [p: (!! p)]

; -- entities --

html-entities: either exists? %entities.c [
	load decompress read/binary %entities.c
][
	load %entities
]
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
keep-char: [set value skip (keep value)]
line: [any [not crlf-set skip] line-ending]
line-ending: [crlf-set not crlf-set]
blank-line: [any sptb-set some crlf-set]
whitespace-char: chset [#20 #09 #0A #0B #0C #0D]
whitespace: [some whitespace-char]
opt-whitespace: [any whitespace-char]
; unicode-whitespace
; space - already defined in Red
non-whitespace-char: complement whitespace-char
ascii-punctuation-char: make bitset! #{000000007FFF003F8000001F8000001E} ; see %scraper.red how to get this [grab 'punct]
; punctuation-char - TODO: see Unicode categories Pc, Pd, Pe, Pf, Pi, Po and Ps


backtick: #"`"
tilde: #"~"
slash: #"/"
backslash: #"\"
amp: #"&"
semicolon: #";"
hash: #"#"
lt: #"<"
gt: #">"
digit: charset "1234567890"
hex-digit: charset "1234567890abcdefABCDEF"
ws: charset " ^-" ; NOTE: newline has special meaning
ws*: [any ws]
ws+: [some ws]
;blank-line: [go-back newline ws* newline]

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
	(!! #t0) pp keep-as-entities
|	(!! #t1) pp if (not code?) named-entities
|	(!! #t2) if (not code?) numeric-entities
|	(!! #t3) entities
|	(!! #t4) if (code?) not newline keep-char ; TODO: Optimize, it same as last line
|	(!! #t5) #"\" entities
|	(!! #t6) [#"\" | 2 space any space] line-ending ahead not end any space (emit emit-value 'br)
|	(!! #t7) pp #"\" set value ascii-punctuation-char (keep value) pp
|	(!! #t8) 2 space ahead [line-ending [end | blank-line]]
|	(!! #t9) [2 space line-ending] ; NOTE: ignore hard break in text
|	(!! #tx) pp not newline (!! #tt) keep-char pp
]

mark: none
go-back: [mark: (mark: back mark) :mark]

; -- raw HTML

wsch*: [any whitespace-char]

lowercase-letter: charset [#"a" - #"z"]
uppercase-letter: charset [#"A" - #"Z"]
ascii-letter: union lowercase-letter uppercase-letter

alphanum: union ascii-letter digit
tag-char: union alphanum charset #"-"
tag-name: [ascii-letter any tag-char]
open-tag: [#"<" tag-name any attribute opt-whitespace opt #"/" #">"]
closing-tag: [#"<" #"/" tag-name opt-whitespace #">"]

attribute-special: charset "_.:-"
attribute-first: union ascii-letter charset ":_"
attribute-char: union alphanum attribute-special
attribute-name: [attribute-first any attribute-char]
attribute-value-specification: [any wsch* #"=" opt-whitespace attribute-value]
attribute-value: [
	unquoted-att-value
|	single-quoted-att-value
|	double-quoted-att-value
]
unquoted-att-chars: complement union whitespace-char charset {"'=<>`}
unquoted-att-value: [some unquoted-att-chars]
single-quoted-att-value: [#"'" some [not #"'" skip] #"'"]
double-quoted-att-value: [#"^"" some [not #"^"" skip] #"^""]
attribute: [some whitespace attribute-name opt attribute-value-specification]

html-comment: ["<!--" not [#">" | "->"] some [not "--" skip] "-->"]
processing-instruction: ["<?" some [not "?>" skip] "?>"]
declaration: ["<!" some uppercase-letter whitespace some [not #">" skip] #">"]
CDATA-section: ["<![CDATA[" some [ahead "]]>" break | not "[[>" skip] "]]>"]
; TODO: COPY in match-tag so the work isn't done twice
match-tag: [
	open-tag
|	closing-tag
|	html-comment
|	processing-instruction
|	CDATA-section
|	declaration
]
html-tag: [copy value match-tag (keep value)]

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
	|	if (setext?) newline (keep newline)
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
	|	if (setext?) newline (keep newline)
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
	(full-trim?: true)
	(stop?: true)
	(push to word! rejoin ['h length? atx-mark])
	some [(!! #ATX-IC) pp inline-content]
	(!! #atend) pp
	(either full-trim? [trim string][trim/tail string])
	(emit-pop)
	(emit-newline)
	(full-trim?: false)
	(stop?: false)
]

; -- setext heading --

setext?: false
setext-type: none
setext-newline?: false

setext-char: charset "=-"
setext-heading-start: [
	(setext?: setext-newline?: false)
	ahead [
		some [
			ahead [0 3 space setext-char] break
		|	newline (setext-newline?: true)
		|	4 space fail
		|	skip
		]
		; at least one line precedes underlining
		if (setext-newline?)
		0 3 space
		copy setext-type [some #"=" | some #"-"]
		(setext-type: select [#"=" h1 #"-" h2] first setext-type)
		any space
		newline
	]
]
setext-heading: [
	setext-heading-start
	(push setext-type)
	(setext?: true)
	(stop?: true)
	any sptb-set
	some [
		ahead [0 3 space setext-char] break
	|	newline
	|	inline-content
	]
	thru newline
	(trim string)
	(emit-pop)
	(emit-newline)
	(stop?: false)
	(setext?: false)
]

; -- block quote --

block-quote-marker: [
	0 3 space
	#">"
]
block-quote: [
	ahead block-quote-marker
	(push 'blockquote)
	(emit-newline)
	some [
		newline (emit-newline)
	|	block-quote-marker any space block-content
	]
	(emit-pop)
	(emit-newline)
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
	|	keep-char
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
code-span-last: none
code-span-end: [ ; backtick string: https://spec.commonmark.org/0.29/#backtick-string
	not backtick set code-span-last skip
	code-span-mark
	not backtick
]
code-span-start: [
	copy code-span-mark some backtick
	ahead to code-span-end
]
code-span-content: [
	code-span-start
	(push 'code)
	(code?: true)
	some [
		code-span-end break
	|	newline (keep space) ; convert to space
	|	text-content
	]
	(
		; NOTE: compensate the SKIP from CODE-SPAN-END
		keep code-span-last
		; NOTE: convert last newline to space
		if newline = last string [change back tail string space]
		; NOTE: strip space if on start and end (but not if just two spaces) 
		if all [
			2 < length? string
			space = first string
			space = last string
		][take string take/last string]
		code?: false
		emit-pop
	)
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
fenced-code-block: [
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
	(mark: tail target)
	(push 'link)
	(insert next mark to url! link-target)
	(if link-title [insert next next mark link-title])
	(emit-value link-text)
	(pop)
]

link-reference-definition: [fail] ; TODO: empty rule until it's done

; -- image --

image-description:
image-target:
image-title:
	none

image-start: [
	"!["
	ahead [to [#"]" #"("]]
]
image-content: [
	image-start
	copy image-description to #"]" skip
	#"(" copy image-target to [space | #")"]
	(image-title: none)
	opt [
		space
		copy image-title to #")"
	]
	#")"
	(mark: target)
	(push 'image)
	(insert next mark to url! image-target)
	(insert next next mark image-description)
	(if image-title [insert next next next mark image-title])
	(pop)
]

; -- list --

comment [
	#NOTE {All rules should follow same structure}
list: [
	start-condition []
	content []
	break-condition []
	end-condition []
	match [
		ahead [
			start-condition
			some [
				break-condition fail
			|	end-condition break
			|	skip
			]
		]
		start-condition
		some [
			end-condition break
		|	content
		]
	]
]
]

bullet-list-marker: charset "-+*"
ordered-chars: charset ".)"
ordered-list-marker: [1 9 digit ordered-chars]

list-marker: [
	bullet-list-marker
|	ordered-list-marker
]

bullet-indent: none

bullet-list-start: [
	; -- start condition
	copy bullet-indent [bullet-list-marker 1 4 space]
	(bullet-indent: length? bullet indent)
	; --
	some [
		; -- break condition
		not bullet-indent space fail
		; -- end condition (same as break condition)
	|	skip	
	]
]

bullet-list-break: [
	not bullet-indent space
]

bullet-list: [
	ahead [
		bullet-list-start
	]
]

; -- para --

para: [
	(push 'para)
	ws*
	(!! #-->para)
	some [
;		blank-line break
		newline ahead newline break
	|	ahead [newline html-break-para] break ; TODO: should break on all blocks
	|	para-newline
	|	inline-content 
	]
	(!! #--<para)
	(trim/tail string)
	(emit-pop)
]

para-newline: [
	newline (
		trim-string
		emit
	)
]

; -- inline --

inline-content: [
	(!! #tc?) ahead thematic-start (!! #tc) break
|	(!! #fc?) ahead fenced-code-start (!! #fc) break
|	(!! #bq?) ahead block-quote-marker (!! #bq) break
|	(!! #csc) code-span-content
|	(!! #stc) strong-content
|	(!! #emc) em-content
|	(!! #ilc) inline-link-content
|	(!! #iim) image-content
|	(!! #hmc) html-tag
|	(!! #lic) line-content (!! #line-ended)
]

line-content: [
	some [
		(!! #check-break) ahead [code-span-start | strong-start | em-start | match-tag] (!! #break-matched ) break
		|	text-content (!! #after-tc)
	]
]

html-block-end: none

html-block-1: [
	; Start condition: line begins with the string <script, <pre, or <style 
	case off
	#"<" ["script" | "pre" | "style"] ; (case-insensitive),
	case on
	;	followed by whitespace, the string >, or the end of the line.
	[whitespace | #">" | crlf]
	; End condition: line contains an end tag </script>, </pre>, or </style> 
	case off
	ahead to html-block-end-1
	(html-block-end: html-block-end-1)
]
html-block-end-1: [
	[</script> | </pre> | </style>]
	case on
]

html-block-2: [
	; Start condition: line begins with the string <!--.
	{<!--}
	; End condition: line contains the string -->.
	ahead to html-block-2-end
	(html-block-end: html-block-2-end)
]
html-block-2-end: {-->}

html-block-3: [
	; Start condition: line begins with the string <?.
	{<?}
	; End condition: line contains the string ?>.
	ahead to html-block-3-end
	(html-block-end: html-block-3-end)
]
html-block-3-end: {?>}

html-block-4: [
	; Start condition: line begins with the string <! followed by an uppercase ASCII letter.
	{<!} uppercase-letter
	;  End condition: line contains the character >.
	ahead to html-block-4-end
	(html-block-end: html-block-4-end)
]
html-block-4-end: #">"

html-block-5: [
	; Start condition: line begins with the string <![CDATA[.
	{<![CDATA[}
	; End condition: line contains the string ]]>.
	ahead to html-block-5-end
	(html-block-end: html-block-5-end)
]
html-block-5-end: {]]>}

html-block-6: [
hb:
(!! #hb6a)
(!! hb)
	; Start condition: line begins the string < or </ followed by one
	; of the strings (case-insensitive) address, article, aside, base,
	; basefont, blockquote, body, caption, center, col, colgroup, dd,
	; details, dialog, dir, div, dl, dt, fieldset, figcaption, figure,
	; footer, form, frame, frameset, h1, h2, h3, h4, h5, h6, head, header,
	; hr, html, iframe, legend, li, link, main, menu, menuitem, nav,
	; noframes, ol, optgroup, option, p, param, section, source, summary,
	; table, tbody, td, tfoot, th, thead, title, tr, track, ul, 
	case off
	#"<" opt slash [
		"address" | "article" | "aside" | "base" | "basefont" | "blockquote" |
		"body" | "caption" | "center" | "col" | "colgroup" | "dd" | "details" |
		"dialog" | "dir" | "div" | "dl" | "dt" | "fieldset" | "figcaption" |
		"figure" | "footer" | "form" | "frame" | "frameset" | "h1" | "h2" |
		"h3" | "h4" | "h5" | "h6" | "head" | "header" | "hr" | "html" |
		"iframe" | "legend" | "li" | "link" | "main" | "menu" | "menuitem" |
		"nav" | "noframes" | "ol" | "optgroup" | "option" | "p" | "param" |
		"section" | "source" | "summary" | "table" | "tbody" | "td" | "tfoot" |
		"th" | "thead" | "title" | "tr" | "track" | "ul"
	]
	case on
(!! #hb6b)
	; followed by whitespace, the end of the line, the string >, or the string />.
	[whitespace | crlf-set | opt slash #">"]
	; End condition: line is followed by a blank line.
(!! #hb6c)
	ahead to html-block-6-end
(!! #hb6d)
	(html-block-end: html-block-6-end)
]
html-block-6-end: [newline [blank-line | end]]

html-block-7: [
	; Start condition: line begins with a complete open tag (with any tag name other than script, style, or pre) or a complete closing tag, followed only by whitespace or the end of the line.
	case off
	#"<" opt slash
	not ["script" | "style" | "pre"]
	thru #">"
	case on
	[whitespace | crlf-set]
	; End condition: line is followed by a blank line.
	ahead to html-block-7-end
	(html-block-end: html-block-7-end)
]
html-block-7-end: [newline [blank-line | end]]

html-block-start: [
	0 3 space [
		(!! #htm1) html-block-1
	|	(!! #htm2) html-block-2
	|	(!! #htm3) html-block-3
	|	(!! #htm4) html-block-4
	|	(!! #htm5) html-block-5
	|	(!! #htm6) html-block-6
	|	(!! #htm7) html-block-7
	]
]

html-break-para: [
	0 3 space [
		(!! #bphtm1) html-block-1
	|	(!! #bphtm2) html-block-2
	|	(!! #bphtm3) html-block-3
	|	(!! #bphtm4) html-block-4
	|	(!! #bphtm5) html-block-5
	|	(!! #bphtm6) html-block-6
	]
]

html-block: [
	copy value html-block-start
	(!! #htm+)
	(keep value)
	some [
		copy value html-block-end (
			; NOTE: BLANK-LINE match keeps previous NEWLINE also, but we need
			;		to ignore it, but only if there's more text after
			all [
				not single? value
				newline = first value
				remove value
			]
			keep value
		) 
		break
	|	keep-char
	]
]

leaf-block: [
	thematic-break
|	(!! #atx) atx-heading
|	(!! #set) setext-heading
|	(!! #ind) indented-code-block
|	(!! #fen) fenced-code-block
|	(!! #htm) html-block (!! #htm-)
|	(!! #lrd) link-reference-definition
|	blank-line
|	para
]

container-block: [
	block-quote
|	list
]

block-content: [
	leaf-block
|	container-block
]
comment [
	blank-line
|	thematic-break
|	atx-heading
|	setext-heading
|	indented-code-block
|	fenced-code
|	block-quote
|	para
]

; -- main --

main-rule: [
	some block-content
]

md: func [input [string!]][
	string: clear ""
	output: clear []
	target: output
	stack: clear []
	stop?: false

	!! parse/case input main-rule
	emit
	output
]

markdown: func [value][lest md value]
