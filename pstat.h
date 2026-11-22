// HW2 (staff): statistics returned by waitstat()
struct pstat {
  int pid;
  int priority;
  int length;
  uint ctime;   // creation tick
  uint etime;   // exit tick
  uint rtime;   // ticks running
  uint wtime;   // ticks waiting for the CPU
};