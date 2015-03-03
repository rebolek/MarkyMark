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
	passed:	make block! 0
	failed:		make block! 0
]

passed: make block! length? tests
failed: make block! length? tests

foreach test tests [
	result: equal? test/html markdown test/markdown
	append either result [passed] [failed] test/example
]

print [
	"=============================" newline
	length? passed "tests passed," length? failed "tests failed." newline
	"CommonMark.reb is" round/to to percent! divide length? passed length? tests 0.01% "ready." 
	newline
	subtract length? passed length? results/passed "improvements" newline
	regressions: max 0 subtract length? failed length? results/failed "regressions" newline
	either zero? regressions "" [join "Check these regressions: " mold difference results/failed failed]
]

save %results context compose/only [
	passed: (passed) 
	failed: (failed)
]