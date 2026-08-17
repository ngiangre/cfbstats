# cfbstats

The goal of this repository is to centralize code for exploring the relationship between coaching and whether players become drafted into the NFL

## Data

`https://api.collegefootballdata.com` including endpoints:

-  [`/draft/picks`](https://api.collegefootballdata.com/api/draft#getdraftpicks): Historical NFL draft picks. Players with the year they were drafted into the NFL.

   Team -> Player -> Year -> NFL Draft Team -> NFL Draft Round

-  [`/coaches`](https://api.collegefootballdata.com/api/coaches#getcoaches): Historical coach records including team, years, and performance.

   Team -> Year -> Coach -> Performance

-  [`/stats/player/season`](https://api.collegefootballdata.com/api/stats#getplayerseasonstats): Player statistics aggregated by season including team, year, and statistics. 

   Team -> Year -> Player -> Performance

