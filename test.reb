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
	"Tests checksum:" enbase tests-checksum newline
	"=============================" newline
	length? passed "tests passed," length? failed "tests failed." newline
	"CommonMark.reb is" round/to to percent! divide length? passed length? tests 0.01% "ready." 
	newline
	improvements: subtract length? passed length? results/passed "improvements" newline
	regressions: max 0 subtract length? failed length? results/failed "regressions" newline
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