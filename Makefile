all:
	mkdir -p build
	nasm -f elf64 main.asm -o build/main.o
	gcc build/main.o -o build/main -lm -no-pie
clean:
	rm -rf build/
