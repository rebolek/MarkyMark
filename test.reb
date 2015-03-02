REBOL[]

do %md.reb

tests: reduce load %tests

success: make block! length? tests
failure: make block! length? tests

foreach test tests [
	result: equal? test/html markdown test/markdown
	append either result [success] [failure] test/example
]

print [length? success "tests passed," length? failure "tests failed."]