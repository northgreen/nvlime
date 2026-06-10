FENNEL := /usr/bin/fennel

# Source files: fnl/ all .fnl, excluding *macros.fnl
FNLS := $(shell find fnl -name '*.fnl' ! -name '*macros.fnl' -type f)
# Source files: after/ all .fnl
FNLS_AFTER := $(shell find after -name '*.fnl' -type f)

# Targets: fnl/xxx.fnl -> lua/xxx.lua
LUAS := $(FNLS:fnl/%.fnl=lua/%.lua)
# after/xxx.fnl -> after/xxx.lua (in-place)
LUAS_AFTER := $(FNLS_AFTER:.fnl=.lua)

.PHONY: all clean check watch status compile help

all: $(LUAS) $(LUAS_AFTER)

# fnl/ -> lua/ (create dir + compile)
lua/%.lua: fnl/%.fnl
	@mkdir -p $(dir $@)
	$(FENNEL) --compile $< > $@

# after/ -> after/ (atomic write)
after/%.lua: after/%.fnl
	$(FENNEL) --compile $< > $@.tmp && mv $@.tmp $@

clean:
	rm -f $(LUAS) $(LUAS_AFTER)

check:
	@missing=""; \
	for f in $(FNLS) $(FNLS_AFTER); do \
		lua="$$(echo $$f | sed 's|^fnl/|lua/|;s|\.fnl$$|.lua|')"; \
		[ ! -f "$$lua" ] && missing="$$missing $$f"; \
	done; \
	if [ -n "$$missing" ]; then \
		echo "Missing compiled outputs:"; \
		for m in $$missing; do echo "  $$m"; done; \
		exit 1; \
	else \
		echo "All $$(( $(words $(FNLS)) + $(words $(FNLS_AFTER)) )) files compiled ✓"; \
	fi

watch:
	@which inotifywait >/dev/null 2>&1 || { echo "Error: inotifywait not found. Install: sudo apt install inotify-tools"; exit 1; }
	@echo "Watching for changes... (Ctrl+C to stop)"
	inotifywait -m -r -e modify,create,delete --format '%w%f' fnl/ after/ 2>/dev/null | \
	while read -r file; do \
		case "$$file" in \
			*.fnl) \
				echo "$$file" | grep -q 'macros\.fnl$$' && continue; \
				if [ -f "$$file" ]; then \
					echo "[compile] $$file"; \
					$(MAKE) compile FILE="$$file" 2>&1 || echo "[error] Failed to compile $$file"; \
				fi; \
			;; \
		esac; \
	done

status:
	@total=$$(($(words $(FNLS)) + $(words $(FNLS_AFTER)))); \
	compiled=0; \
	for f in $(FNLS) $(FNLS_AFTER); do \
		lua="$$(echo $$f | sed 's|^fnl/|lua/|;s|\.fnl$$|.lua|')"; \
		[ -f "$$lua" ] && compiled=$$((compiled + 1)); \
	done; \
	echo "Fennel files: $$total | Compiled: $$compiled | Not compiled: $$((total - compiled))"

compile:
	@if [ -z "$(FILE)" ]; then echo "Usage: make compile FILE=fnl/foo.fnl"; exit 1; fi
	@if [ ! -f "$(FILE)" ]; then echo "File not found: $(FILE)"; exit 1; fi
	@luapath="$$(echo "$(FILE)" | sed 's|^fnl/|lua/|;s|\.fnl$$|.lua|')"; \
	echo "$(FILE)" | grep -q '^after/' && luapath="$$(echo "$(FILE)" | sed 's|\.fnl$$|.lua|')"; \
	mkdir -p $$(dirname "$$luapath"); \
	$(FENNEL) --compile $(FILE) > "$$luapath" 2>&1 && echo "[ok] $(FILE) → $$luapath" || { rm -f "$$luapath" && exit 1; }

help:
	@echo "NVLIME Fennel Build"
	@echo ""
	@echo "Targets:"
	@echo "  all      - Compile all Fennel files (default)"
	@echo "  clean    - Remove all compiled .lua files"
	@echo "  check    - Verify all .fnl files have corresponding .lua"
	@echo "  status   - Show compilation statistics"
	@echo "  watch    - Watch for changes and auto-compile (requires inotify-tools)"
	@echo "  compile  - Compile a single file (e.g. make compile FILE=fnl/foo.fnl)"
	@echo "  help     - Show this help"
