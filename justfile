# just --list
default:
   just --list

# start claude code with preferred settings
claude:
   claude --dangerously-skip-permissions --model="sonnet"

make:
	make

run: make
	./bin/svim
