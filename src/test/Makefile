.PHONY: all test help

# --- Configuration Variables ---
TEST_RUNNER := ./test.sh
TEST_WATCHER := ./testwatcher.sh
AREA ?=

# --- Targets ---

all: test

test:
	@echo "--- Running Tests ---"
ifeq ($(AREA),)
	$(TEST_WATCHER)
	$(TEST_RUNNER)
else
	$(TEST_RUNNER) $(AREA)
endif
	@echo "--- Tests Finished ---"


%:
	@if [ "$*" != "all" ] && [ "$*" != "test" ] && [ "$*" != "help" ] && [ "$*" != "build" ] && [ "$*" != "clean" ]; then \
		echo "--- Running Specific Test: $* ---"; \
		if [ -f "$*Test.sh" ]; then \
			$(TEST_RUNNER) "$*Test.sh"; \
		else \
			$(TEST_RUNNER) "$*"; \
		fi \
	fi

.PHONY: $(wildcard *Test.sh)

$(wildcard *Test.sh): %:
	@echo "--- Running Test Script: $* ---"
	$(TEST_RUNNER) $*

build:
	@echo "No build commands defined."

clean:
	@echo "No clean commands defined."

# --- Help Target ---
help:
	@echo "Usage:"
	@echo "  make               - Run all tests (default)"
	@echo "  make test          - Run all tests (same as 'make')"
	@echo "  make test AREA=<test_name> - Run specific tests"
	@echo "  make <test_name>   - Run a specific test script (e.g., 'make library' will run 'libraryTest.sh')"
	@echo "  make <test_name>Test.sh - Run a specific test script directly (e.g., 'make libraryTest.sh')"
	@echo "  make build         - Build the project"
	@echo "  make clean         - Clean generated files"
	@echo ""
	@echo "Variables:"
	@echo "  AREA: Specify a subset of tests to run (e.g., AREA=library)"

