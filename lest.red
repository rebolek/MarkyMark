Red[]

lest: func [
	data [block!]
	/local out rule para value target
][
	out: clear ""
	tag-stack: clear []
	para: [
		'para (append out <p>)
		ahead block! into rule
		; NEWLINE goes after </p>
		(if equal? newline last out [take/last out])
		(append out </p>)
		(append out newline)
	]
	tag-rule: [
		set tag [
			'em | 'strong | 'pre | 'blockquote
			| 'h1 | 'h2 | 'h3 | 'h4 | 'h5 | 'h6
		]
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
				(append out rejoin [{ class=language-"} form class {"}])
			]
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
