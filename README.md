# TPC-C experiments
Experiments were performed using [benchbase](https://github.com/cmu-db/benchbase).

Each experiment ran for 20 minutes (for each parameter combination).

Scale factor was equal to 1000, which means around 70GBs of data in each database.

Rate parameter was set to 100000.

In detailed tests, each test was run with warmup = 120 seconds.

I tested two databases: one based on HDD drive, and the second one based on SSD drive.

## Postgres

Initial tests folder contains tests that I ran a month ago, for different sets of parameters, but without keeping detailed data. Detailed tests folder contains benchmarks for only the default parameters, but with detailed metrics such as cache hits. Notebooks for the initial tests were created by me, and for the detailed ones, I used GeminiCLI (it used data that I provided).

It took me a while to get to the second round of benchmarking, mostly because I couldn't repeat the phenomenal results of the SSD drive. And it was running even slower than the HDD drive. Main bottleneck seemed to be locks, and it seemd that it was also the reason why HDD drive performed so poorly in the initial tests. Thing is, the initial tests were run with SEQUENTIAL isolation level. In this mode, Postgres creates a lot of SIReadLocks. They don't lock anything, but  Postgres uses them to order the data, and they count to the overall lock limit. After changing the isolation level to READ_COMMITTED (postgres default), I got rid of that issue (and a lot of locks). You can read more about it [here](https://baida.dev/articles/post-mortem-postgres-out-of-shared-memory-error).

Still though, in the second round of benchmarks, you can clearly notice that while HDD performs better, SDD performance is much worse, its not much faster than the HDD drive. And, in the backup folders, you will see the data from the same benchmark, but in which both drives perform similarly. my main take-away is that HDD drive has more cache hits, but on the other hand the difference is not that big and I would still expect the SSD drive to perform much better.

On 02.04.2026, Paweł managed to restart the Postgres server. Results after that are available under `detailed_server_restart` directory.
Now, SSD again pefrorms as expected, but the HDD drive now performs almost the same. I suspect this is because of the RAID configuration, as now many HDD drives are serving requests, not just one.
The only clear benefit is lower overal latency for each query on SSD drive, but I don't think this jusifies the price.
At this point, I decided to move on with testing MAriaBD instead, to see if there are differences not between drives, but between databases.

NOTE: you may notice that GOODPUT is higher than THROUGHPUT in some places. I thought that I have a bug somewhere, but apparently this is an issue with the `benchbase` suite if one uses warmup (https://github.com/cmu-db/benchbase/issues/606).

## MariaDB
`init_bench` directory under `mariadb/ssd` contains initial run of the benchmark. It seems that it perform 3x slower than Postgres. However, I noticed some differences in the configuration:
- Maria ignores `READ_COMMITTED` parameter from benchbase, so I had to set in manually.
- I set `sort_buffer_size` and `join_buffer_size` to match `work_memory` of postgres (128MiB).
- I increased `innodb_io_capacity` and `innodb_io_capacity_max` to 2000 and 4000 respectively.

Results of that are visible under `applied_params_bench`.
And well, there is no difference really. At this point I learned that MariaDB uses DIRECT IO, while Postgres does not. I turned it off for MariaDB, but as you can see in `direct_io_off`, now it's even worse.
At this point I decided to wrap the project up. I would probably have to modify params that require server restart to make Maria perform reasonably, and I don't have permissions for that (e.g. buffer pool size). And even if I had,
then I wouls also have to rerun Postgres benchmarks, and Postgres cluster is shared with students databases, so it would be suboptimal.

For the sake of completeness, I also ran MariaDB on HDD. I decided to not include DIRECT IO OFF tests this time. As you can see, MariaDB is VERY slow. Which probably isn't its fault, but the previous point stands.

## Bonus: Postgres on Google Drive
A few notes on my failed attempt to run Postgres on Google drive:
- Google Drive is lock storage, so if a database is large, sending whole files when a single page needs to be updated is suboptimal. Combine that with caching done by `rclone`, and your database is only poorly replicated to the cloud. A nice idea would be to write FUSE fs that would keep each page as object (so one file -> many objects). That, however, would still be too slow.
- ISO providers seem to block port 445; so when using "Storage Box" from Hetzner, I wasn't able to use SMB for fast NFS.
- `sshfs` is too slow to handle Postgres, even with databases having < 1GiB of data.