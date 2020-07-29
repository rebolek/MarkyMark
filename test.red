Red[]

#include %mm.red

select-test: func [id] [
	forall tests [
		all [
			equal? id tests/1/example
			return tests/1
		]
	]
]

do-test: function [id] [
	test: select-test id
	print test/markdown
	print test/html
	print markdown test/markdown 
]

debug: func [id /local result passed? passed failed] [
	passed: clear make block! 50
	failed: clear make block! 50
	local: compose [(id)]
	foreach id local [
		t: select-test id
		result: markdown t/markdown
		if equal? 1 length? local [
			print t/section
			print mold t/markdown
			print mold t/html
			print join newline mold markdown/debug t/markdown
		] 
		print ["*** Test" t/example either passed?: equal? result t/html "passed" "failed" " ***"]
		append either passed? [passed][failed] t/example
	]
	print [
		newline 
		"Passed: " length? passed newline 
		"Failed: " length? failed newline
	]
]

section: function [index] [
	sections: clear []
	section-map: make map! []
	foreach test tests [
		s: test/section
		sections: union sections reduce [s]
;		sec: select section-map s
;		default sec make block! 100
		sec: any [
			select section-map s
			make block! 100
		]
		append sec test/example
		section-map/:s: sec
	]
	select section-map pick sections index
]

status: function [] [
	sections: clear []
	section-passed: make map! []
	section-failed: make map! []
	foreach test tests [
		s: test/section
		sections: union sections reduce [s]
;		passed: select section-passed s
;		default passed make block! 100
		passed: any [
			select section-passed s
			make block! 100
		]
;		failed: select section-failed s
;		default failed make block! 100
		failed: any [
			select section-failed s
			make block! 100
		]
		append either equal? test/html markdown test/markdown [passed][failed] test/example
		section-passed/:s: passed
		section-failed/:s: failed
	]
	print "ID - section name [ passed / failed ]"
	repeat index sections [
		print rejoin [index? index " - " index/1 " [" p: length? pick section-passed index/1 "/"  f: length? pick section-failed index/1 " (" round/to to percent! p / (p + f) 0.01% ")]"]
	]
]

; ---------------------------------------------------------------------------

tests: reduce load %tests.red

results: if exists? %results [do %results]
unless results [
	results: context [
		script-checksum:	checksum to binary! mold read %mm.red 'SHA1
		tests-checksum:		checksum to binary! mold read %tests.red 'SHA1
		passed:				make block! 0
		failed:					make block! 0
	]
]

passed: 				make block! length? tests
failed: 				make block! length? tests
script-checksum:	checksum to binary! mold read %mm.red 'SHA1
tests-checksum:		checksum to binary! mold read %tests.red 'SHA1

hr: func [value /local line][
	unless value [print append/dup clear "" #"#" 80 exit]
	line: rejoin ["## " value space]
	append/dup line #"#" 80 - length? line
	print line
]

test: func [number [integer!]][
	markdown tests/:number/markdown
]

check: func [number [integer!] /quiet][
	unless quiet [
		hr "markdown"
		print tests/:number/markdown
		hr "expected"
		print tests/:number/html
		hr "result"
		print markdown tests/:number/markdown
		hr none
	]
	equal? tests/:number/html markdown tests/:number/markdown
]

get-sections: func [
	/local test section
][
	sections: make map! []
	foreach test tests [
		section: test/section
		unless sections/:section [sections/:section: copy []]
		append sections/:section test/example
	]
	sections
]

check-section: func [name /local passed test section][
	passed: clear []
	section: select sections name
	foreach test section [
		if check/quiet test [append passed test]
	]
	hr name
	print ["Total: " length? section]
	print ["Passed:" passed]
	print ["Rate:  " to percent! round/to (length? passed) / (1.0 * length? section) 0.01%]
]


main: func [/local test][
	foreach test tests [
		print test/example
		result: equal? test/html markdown test/markdown
		append either result [passed] [failed] test/example
	]

	#TODO {
		The logic here is wrong. Total numbers may be fine, but the difference is
		poblematic. need to look into it.
	}

	print [
		"=============================" newline
		"Script checksum:" enbase script-checksum newline
		"Tests checksum: " enbase tests-checksum newline
		"=============================" newline
		length? passed "tests passed," length? failed "tests failed." newline
		"CommonMark.reb is" to percent! round/to divide length? passed length? tests 0.01% "ready." 
		newline
		improvements: max 0 subtract length? passed length? results/passed "improvements" newline
		regressions: max 0 subtract length? failed length? results/failed "regressions" newline
		either zero? improvements [""][rejoin ["Check these improvements: " mold difference results/passed passed]]
		either zero? regressions [""][rejoin ["Check these regressions: " mold difference results/failed failed]]
	]

	if any [
		not zero? improvements
		not zero? regressions
		not equal? script-checksum results/script-checksum
		not equal? tests-checksum results/tests-checksum
	] [
		save/header %results context compose/only [
			script-checksum: 	(script-checksum)
			tests-checksum: 	(tests-checksum)
			passed: 				(passed) 
			failed: 				(failed)
		][]
	]
]

main
