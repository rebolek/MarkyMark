Red[
	entities: https://html.spec.whatwg.org/entities.json
]

; entities

context [
	link: https://html.spec.whatwg.org/entities.json
	ent: load link
	set 'entities collect [
		foreach [key value] ent [
			if string? key [
				take key
				take/last key
				keep key
				keep/only value/codepoints
			]
		]
	]
	new-line/skip entities true 2
]

; specs

context [

link: https://spec.commonmark.org/0.29/#ascii-punctuation-character

page: read link

entities: [
	"&lt;"		#"<"
	"&gt;"		#">"
	"&amp;"		#"&"
	"&quot;"	#"^""
]

grab-punctuation: func [/local value take][
	punct: copy []
	take: quote (
		append punct either 1 = length? value [
			to char! value
		][
			select entities value
		]
	)
	parse page [
		thru "ASCII punctuation character"
		thru </a>
		some [
			<code> copy value to #"<" </code> take
		|	</p> break
		|	skip
		]
	]
	punct
]

	set 'grab func [value][
		switch value [
			punct [grab-punctuation]
		]
	]
]
