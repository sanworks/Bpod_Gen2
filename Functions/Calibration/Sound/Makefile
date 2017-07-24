all: cmd_acq

cmd_acq.o: cmd_acq.c
	gcc -c cmd_acq.c

cmd_acq: cmd_acq.o
	gcc -o cmd_acq cmd_acq.o -lcomedi -lm 

clean:
	rm -f *.o cmd_acq *~ *.dat

