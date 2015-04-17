REBOL[]

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
		append either passed? [passed] [failed] t/example
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
		sec: select section-map s
		default sec make block! 100
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
		passed: select section-passed s
		default passed make block! 100
		failed: select section-failed s
		default failed make block! 100
		append either equal? test/html markdown test/markdown [passed] [failed] test/example
		section-passed/:s: passed
		section-failed/:s: failed
	]
	print "ID - section name [ passed / failed ]"
	repeat index sections [
		print rejoin [index? index " - " index/1 " [" p: length? pick section-passed index/1 "/"  f: length? pick section-failed index/1 " (" round/to to percent! p / (p + f) 0.01% ")]"]
	]
]

do %md.reb

tests: reduce load %tests
results: if exists? %results [do %results]
default results context [
	script-checksum:	checksum/method to binary! mold read %md.reb 'SHA1
	tests-checksum:		checksum/method to binary! mold read %tests 'SHA1
	passed:				make block! 0
	failed:					make block! 0
]

passed: 				make block! length? tests
failed: 				make block! length? tests
script-checksum:	checksum/method to binary! mold read %md.reb 'SHA1
tests-checksum:		checksum/method to binary! mold read %tests 'SHA1

foreach test tests [
	result: equal? test/html markdown test/markdown
	append either result [passed] [failed] test/example
]

print [
	"=============================" newline
	"Script checksum:" enbase script-checksum newline
	"Tests checksum: " enbase tests-checksum newline
	"=============================" newline
	length? passed "tests passed," length? failed "tests failed." newline
	"CommonMark.reb is" round/to to percent! divide length? passed length? tests 0.01% "ready." 
	newline
	improvements: max 0 subtract length? passed length? results/passed "improvements" newline
	regressions: max 0 subtract length? failed length? results/failed "regressions" newline
	either zero? improvements "" [join "Check these improvements: " mold difference results/passed passed]
	either zero? regressions "" [join "Check these regressions: " mold difference results/failed failed]
]

if any [
	not zero? improvements
	not zero? regressions
	not equal? script-checksum results/script-checksum
	not equal? tests-checksum results/tests-checksum
] [
	save %results context compose/only [
		script-checksum: 	(script-checksum)
		tests-checksum: 	(tests-checksum)
		passed: 				(passed) 
		failed: 				(failed)
	]
]