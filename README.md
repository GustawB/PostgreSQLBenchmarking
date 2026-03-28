# TPC-C experiments
Experiments were performed using [benchbase](https://github.com/cmu-db/benchbase).

Each experiment ran for 20 minutes (for each parameter combination).

Scale factor was equal to 1000, which means around 70GBs of data in each database.

Rate parameter was set to 100000.

In detailed tests, each test was run with warmup = 120 seconds.

I tested two databases: one based on HDD drive, and the second one based on SSD drive.

Initial tests folder contains tests that I ran a month ago, for different sets of parameters, but without keeping detailed data. Detailed tests folder contains benchmarks for only the default parameters, but with detailed metrics such as cache hits. Notebooks for the initial tests were created by me, and for the detailed ones, I used GeminiCLI (it used data that I provided).

It took me a while to get to the second round of benchmarking, mostly because I couldn't repeat the phenomenal results of the SSD drive. And it was running even slower than the HDD drive. Main bottleneck seemed to be locks, and it seemd that it was also the reason why HDD drive performed so poorly in the initial tests. Thing is, the initial tests were run with SEQUENTIAL isolation level. In this mode, Postgres creates a lot of SIReadLocks. They don't lock anything, but  Postgres uses them to order the data, and they count to the overall lock limit. After changing the isolation level to READ_COMMITTED (postgres default), I got rid of that issue (and a lot of locks). You can read more about it [here](https://baida.dev/articles/post-mortem-postgres-out-of-shared-memory-error).

Still though, in the second round of benchmarks, you can clearly notice that while HDD performs better, SDD performance is much worse, its not much faster than the HDD drive. And, in the backup folders, you will see the data from the same benchmark, but in which both drives perform similarly. my main take-away is that HDD drive has more cache hits, but on the other hand the difference is not that big and I would still expect the SSD drive to perform much better.