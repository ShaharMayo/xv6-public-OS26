// HW2 (staff): scheduling workload. Prints one TSV row per job.
// Usage: schedtest                      (same as exp1)
//        schedtest exp1 | exp2 | exp3
//        schedtest [priority length arrival]...
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
#define NELEM(x) (sizeof(x) / sizeof((x)[0]))

struct job {
  int priority;
  int length;
  int arrival;
  int pid;
};

// Experiment 1: jobs keep arriving between scheduling decisions.
struct job exp1[] = {
  {1, 50, 20}, {3, 30, 0}, {5, 10, 40}, {4, 200, 10}, {2, 20, 85},
};

// Experiment 2: four identical jobs, all present from the start.
struct job exp2[] = {
  {1, 150, 0}, {1, 150, 0}, {1, 150, 0}, {1, 150, 0},
};

// Experiment 3: a mix of short and long jobs arriving over time.
struct job exp3[] = {
  {1, 70, 0}, {1, 8, 54}, {1, 150, 57}, {1, 15, 86},
  {1, 25, 108}, {1, 40, 147}, {1, 20, 155}, {1, 12, 185},
};

struct job jobs[MAXJOBS];
int njobs;
char *wname;

void
load(char *name, struct job *src, int n)
{
  wname = name;
  njobs = n;
  memmove(jobs, src, n * sizeof(struct job));
}

int
main(int argc, char *argv[])
{
  int i, j, pid;
  struct pstat st;
  struct pstat res[MAXJOBS];

  if(argc == 1 || (argc == 2 && strcmp(argv[1], "exp1") == 0)){
    load("exp1", exp1, NELEM(exp1));
  } else if(argc == 2 && strcmp(argv[1], "exp2") == 0){
    load("exp2", exp2, NELEM(exp2));
  } else if(argc == 2 && strcmp(argv[1], "exp3") == 0){
    load("exp3", exp3, NELEM(exp3));
  } else {
    if((argc - 1) % 3 != 0 || (argc - 1) / 3 > MAXJOBS){
      printf(2, "usage: schedtest [exp1 | exp2 | exp3 | priority length arrival ...]\n");
      exit();
    }
    wname = "custom";
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

  printf(1, "SCHEDTEST\tworkload\tpolicy\tquantum\tjob\tpid\tpriority\tlength\tarrival\tturnaround\twaiting\trunning\tresponse\n");
  for(i = 0; i < njobs; i++)
    printf(1, "SCHEDTEST\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\n",
           wname, SCHED_NAME, QUANTUM, i, res[i].pid, res[i].priority,
           res[i].length, jobs[i].arrival, res[i].etime - res[i].ctime,
           res[i].wtime, res[i].rtime, res[i].resp);
  exit();
}