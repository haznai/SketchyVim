# just --list
default:
   just --list

# start claude code with preferred settings
claude:
   claude --dangerously-skip-permissions --model="sonnet"

make:
	make

run: make
	rm -rf /tmp/svim_attributed_debug.log
	./bin/svim
