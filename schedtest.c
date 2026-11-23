// HW2 (staff): scheduling workload. Prints one TSV row per job.
// Usage: schedtest [priority length]...
#include "types.h"
#include "stat.h"
#include "user.h"
#include "pstat.h"

#ifndef SCHED_NAME
#define SCHED_NAME "RR"
#endif
#ifndef QUANTUM
#define QUANTUM 1
#endif

#define MAXJOBS 16

struct job {
  int priority;
  int length;
  int arrival;
  int pid;
};

struct job jobs[MAXJOBS] = {
  {4, 20, 20}, {3, 50, 0}, {5, 10, 40}, {1, 200, 10}, {2, 100, 30},
};
int njobs = 5;

int
main(int argc, char *argv[])
{
  int i, j, pid;
  struct pstat st;
  struct pstat res[MAXJOBS];

  if(argc > 1){
    if((argc - 1) % 3 != 0 || (argc - 1) / 3 > MAXJOBS){
      printf(2, "usage: schedtest [priority length arrival]...\n");
      exit();
    }
    njobs = (argc - 1) / 3;
    for(i = 0; i < njobs; i++){
      jobs[i].priority = atoi(argv[1 + 3*i]);
      jobs[i].length = atoi(argv[2 + 3*i]);
      jobs[i].arrival = atoi(argv[3 + 3*i]);
    }
  }

  // Create all jobs. Each child burns `length` ticks of CPU and exits.
  for(i = 0; i < njobs; i++){
    pid = fork();
    if(pid < 0){
      printf(2, "schedtest: fork failed\n");
      exit();
    }
    if(pid == 0){
      while(runticks() < jobs[i].length)
        ;
      exit();
    }
    jobs[i].pid = pid;
    setsched(pid, jobs[i].priority, jobs[i].length, jobs[i].arrival);
  }

  // Collect statistics as the children finish.
  for(i = 0; i < njobs; i++){
    if(waitstat(&st) < 0)
      break;
    for(j = 0; j < njobs; j++)
      if(jobs[j].pid == st.pid)
        memmove(&res[j], &st, sizeof(st));
  }

  printf(1, "SCHEDTEST\tpolicy\tquantum\tjob\tpid\tpriority\tlength\tarrival\tturnaround\twaiting\trunning\tresponse\n");
  for(i = 0; i < njobs; i++)
    printf(1, "SCHEDTEST\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n",
           SCHED_NAME, QUANTUM, i, res[i].pid, res[i].priority, res[i].length,
           jobs[i].arrival, res[i].etime - res[i].ctime, res[i].wtime,
           res[i].rtime, res[i].resp);
  exit();
}