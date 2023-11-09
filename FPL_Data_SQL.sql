-- Task is to identify trends in:

--- 1. Player Performance
--- 2. Team Analysis
--- 3. Fixture Difficulty

-- There are 4 tables in the schema:

--- points_df contains the points per gameweek per player id
--- positions_df contains the names of the positions per position id
--- teams_df contains information about each team id
--- players_df contains the names, teams, positions of each player

-- Player Performance

--- Need to first join on the team names and the positions names onto the players_df
--- Create cte that joins positions onto player ids
--- Join on the team names on the element_types

WITH cte AS (
    SELECT play.*, pos.singular_name AS position
    FROM players_df play
    JOIN positions_df pos ON play.element_type = pos.id
)
SELECT cte.id, cte.web_name AS name, cte.position, t.name AS team_name
FROM cte
JOIN teams_df t ON cte.team = t.id



-- Now can look at joining some of the point variables onto the df 

CREATE TABLE Player_Points AS
with cte_2 as (
WITH cte AS (
    SELECT play.*, pos.singular_name AS position
    FROM players_df play
    JOIN positions_df pos ON play.element_type = pos.id
)
SELECT cte.id, cte.web_name AS name, cte.position, t.name AS team_name
FROM cte
JOIN teams_df t ON cte.team = t.id)
select cte_2.*, pt.round, pt.value,
pt.opponent_team, pt.total_points, pt.was_home as home_indicator, pt.team_h_score , 
pt.team_a_score , pt.minutes, pt.goals_scored, pt.assists, pt.clean_sheets,
pt.red_cards, pt.bps,pt.expected_goals as XG , pt.expected_assists as XA , pt.expected_goal_involvements as XGI, 
pt.expected_goals_conceded as XGC
from cte_2
join points_df pt on cte_2.id = pt.element;

select *
from player_points 
limit 5;

-- Creating column current_value where it is the most recent value data per player

SELECT id, value
FROM player_points
WHERE round IN (
    SELECT MAX(round)
    FROM player_points
    GROUP BY id
);

ALTER TABLE player_points
ADD COLUMN current_value float;

WITH current_values AS (
    SELECT id, value
    FROM player_points
    WHERE round IN (
        SELECT MAX(round)
        FROM player_points
        GROUP BY id
    )
)
UPDATE player_points AS pp
SET current_value = cv.value
FROM current_values AS cv
WHERE pp.id = cv.id;

-- Checking current value is correct
select name, current_value, value 
from player_points
where id = 42;

-- Aggregations & Analysis of data

-- top 5 point scores are salah, son, haaland, watkins and mbeumo
-- top 5 total xgi accumed is haaland, salah, mbeumo, Jackson and saka
-- Suggests there is overlap & correlation between XGI and total_points



select
name, team_name,
sum(total_points) as total_points,
sum(goals_scored) as total_goals_scored, 
sum(assists) as total_assists, 
sum(xg) as total_xg,
sum(xa) as total_xa,
sum(xgi) as total_xgi
from player_points 
group by name, team_name
order by total_points DESC
limit 5;

select
name, team_name,
sum(total_points) as total_points,
sum(goals_scored) as total_goals_scored, 
sum(assists) as total_assists, 
sum(xg) as total_xg,
sum(xa) as total_xa,
sum(xgi) as total_xgi
from player_points 
group by name, team_name
order by total_xgi DESC
limit 5;

-- Correlation calculation between variables
-- Points is highly correlated with XGI
-- Goals highly correlated with XG
-- Assists highly correlated with XA

-- Therefore, expected columns are highly useful in predicting variables relating to points

with cte as(
select
name, team_name,
sum(total_points) as total_points,
sum(goals_scored) as total_goals_scored, 
sum(assists) as total_assists, 
sum(xg) as total_xg,
sum(xa) as total_xa,
sum(xgi) as total_xgi
from player_points 
group by name, team_name
order by total_xgi DESC
limit 5)
SELECT CORR (total_points , total_xgi) as point_xgi_corr,
CORR(total_points, total_xg) as point_xg_corr,
CORR(total_points, total_xa) as point_xa_corr,
CORR(total_goals_scored, total_xg) as goals_xg_corr,
CORR(total_assists, total_xa) as assists_xa_corr
from cte;

-- looking at the distribution of points home and away
-- Filtering to only look at players who play 60 or more minutes
-- Higher values of points and xgi occur at home
-- Potentially explained by the increase in goals scored at home compared to away

select home_indicator, avg(total_points) as avg_points,
avg(xgi) as avg_xgi, avg(team_h_score) as avg_h_goals, avg(team_a_score) as avg_a_goals
from player_points
where minutes >= 60
group by home_indicator;

-- looking at the defensive players

select *
from player_points 
limit 5;


-- Tripper, Andersen, White, Mitchell and Saliba are the higest defenders.
-- Tripper in particular is significantly higher than the other defenders
-- Potentially due to high xgi value & bps values

select name, team_name, sum(total_points) as sum_of_points, sum(bps) as total_bps, 
sum(xgi) as total_xgi , sum(clean_sheets) as total_cs
from player_points 
where position ='Defender'
group by name, team_name
order by sum_of_points desc
limit 10;

-- Looking at the correlation between points and the bps, xgi, and cs
-- bps has a high correlation with points
-- Intuitively makes sense as bpi is derived by typical point scoring actions (goals, assists, cs) but also leads to additional
-- bonus points for players. 

with defenders as
(select name, team_name, sum(total_points) as sum_of_points, sum(bps) as total_bps, 
sum(xgi) as total_xgi , sum(clean_sheets) as total_cs
from player_points 
where position ='Defender'
group by name, team_name
order by sum_of_points desc
limit 10)
SELECT CORR (sum_of_points , total_bps) as point_bps_corr,
CORR(sum_of_points, total_xgi) as point_xgi_corr,
CORR(sum_of_points, total_cs) as point_cs_corr
from defenders;

-- Team Analysis

-- the original team df has useful strength coefficients of a teams strength
-- these are not dynamic though (i.e. created at the start of the season)
-- creating df for each game and team

-- some observatios have players who were previously playing for a different team
-- i.e. Raya in GW 1 played for brentford but is down as an arsenal player in the df.

select team_name, round, home_indicator,
MODE() WITHIN GROUP (ORDER BY team_h_score) AS home_goals,
MODE() WITHIN GROUP (ORDER BY team_a_score) AS away_goals,
sum(xg) as total_xg
from player_points
group by team_name, round, home_indicator
order by team_name, round;

-- Can look to join on team strengths

-- Creating first cte which has the team variables from the player_points df (aggregations)
-- Joining on the overall, attacking, and defensive strengths (Conditionally)
-- Finally using 2nd cte to create windows (dense) rank column of strengths home and away

CREATE TABLE team_data As
with team_cte_2 as 
(with team_cte as
(select team_name, round, home_indicator,
MODE() WITHIN GROUP (ORDER BY team_h_score) AS home_goals,
MODE() WITHIN GROUP (ORDER BY team_a_score) AS away_goals,
sum(xg) as total_xg
from player_points
group by team_name, round, home_indicator
order by team_name, round)
select tm_cte.*, 
case 
	when home_indicator is true then tm.strength_overall_home
	else tm.strength_overall_away
end as overall_strength,
case 
	when home_indicator is true then tm.strength_attack_home
	else tm.strength_attack_away
end as attacking_strength,
case 
	when home_indicator is true then tm.strength_defence_home
	else tm.strength_defence_away
end as defending_strength
from team_cte tm_cte
join teams_df tm on tm_cte.team_name = tm."name")
select team_cte_2.*, 
DENSE_RANK() over (partition by home_indicator order by overall_strength DESC) as Strength_rank,
DENSE_RANK() over (partition by home_indicator order by attacking_strength DESC) as Attack_rank,
DENSE_RANK() over (partition by home_indicator order by defending_strength DESC) as Defence_rank
from team_cte_2

-- Can look at analysing the new df

-- Assessing the the best teams

select * 
from team_data
limit 5;

-- Man City are the best team in overall, attacking, and defensive strength both home and away

select team_name,home_indicator, avg(strength_rank) as strength_rank, avg(attack_rank) as attack_rank,
avg(defence_rank) as defence_rank
from team_data
where strength_rank = ( SELECT MIN(strength_rank) FROM team_data )
or attack_rank = (select MIN (attack_rank) from team_data)
or defence_rank = (select min (defence_rank) from team_data)
group by team_name, home_indicator ;

-- Sheffield Utd and Luton are the worst teams at home whilst Luton is also the worst team away

select team_name,home_indicator, avg(strength_rank) as strength_rank, avg(attack_rank) as attack_rank,
avg(defence_rank) as defence_rank
from team_data
where strength_rank = ( SELECT MAX(strength_rank) FROM team_data )
or attack_rank = (select MAX (attack_rank) from team_data)
or defence_rank = (select MAX (defence_rank) from team_data)
group by team_name, home_indicator ;


--- FIXTURES

-- need to join the attacking, overall & defensive strengths onto the fixtures df for both home & away
-- Once done can look at difference between home attack and away defence (and away attack vs home defence)
-- firstly adding the team names & team strengths

select *
from fixtures_df
limit 5;

-- amending the event_name to just the numbers and making int type


-- There are two rows with no gamewek. This is the fixture between Man city and Brentford that is to be rearranged
-- Can drop these rows for simplicity

SELECT *
FROM fixtures_df fd 
WHERE NOT RIGHT(event_name, 2) ~ '^[0-9]+$' OR event_name = '';

DELETE FROM fixtures_df
WHERE NOT RIGHT(event_name, 2) ~ '^[0-9]+$' OR event_name = '';

-- Can now amend to just the numbers for the gameweeks

UPDATE fixtures_df
SET event_name = CAST(RIGHT(event_name, 2) AS INTEGER);

select *
from fixtures_df;



with fix_2 as 
(select fix.*, td."name" as home_team, 
td.strength_overall_home , 
td.strength_attack_home , td.strength_defence_home  
from fixtures_df fix
join teams_df td on fix.team_h = td.id)
select fix_2.* , td2."name" as away_team, td2.strength_overall_away ,
td2.strength_attack_away , td2.strength_defence_away 
from fix_2
join teams_df td2 on fix_2.team_a = td2.id

team_h, team_a, event_name, is_home, home_team, strength_overall_home, strength_attack_home, strength_defence_home, away_team, strength_overall_away, strength_attack_away, strength_defence_away


-- Need to now calculate difficulty of fixtures over a defined perdiod (say 5 & 10)
-- Transforming so each row is about a particular team

WITH fix_2 AS (
    SELECT fix.*, 
           td."name" AS home_team, 
           td.strength_overall_home AS home_overall_strength,
           td.strength_attack_home AS home_attack_strength,
           td.strength_defence_home AS home_defence_strength,
           td2."name" AS away_team,
           td2.strength_overall_away AS away_overall_strength,
           td2.strength_attack_away AS away_attack_strength,
           td2.strength_defence_away AS away_defence_strength
    FROM fixtures_df fix
    JOIN teams_df td ON fix.team_h = td.id
    JOIN teams_df td2 ON fix.team_a = td2.id
)

SELECT event_name,
    CASE 
        WHEN fix_2.is_home THEN fix_2.home_team
        ELSE fix_2.away_team
    END AS team_name,
    fix_2.is_home,
    CASE 
        WHEN fix_2.is_home THEN fix_2.home_overall_strength
        ELSE fix_2.away_overall_strength
    END AS overall_strength,
    CASE 
        WHEN fix_2.is_home THEN fix_2.home_attack_strength
        ELSE fix_2.away_attack_strength
    END AS attack_strength,
    CASE 
        WHEN fix_2.is_home THEN fix_2.home_defence_strength
        ELSE fix_2.away_defence_strength
    END AS defence_strength,
    CASE 
        WHEN fix_2.is_home THEN fix_2.away_team
        ELSE fix_2.home_team
    END AS opposition_name,
    CASE 
        WHEN NOT fix_2.is_home THEN fix_2.home_overall_strength
        ELSE fix_2.away_overall_strength
    END AS opposition_overall_strength,
    CASE 
        WHEN NOT fix_2.is_home THEN fix_2.home_attack_strength
        ELSE fix_2.away_attack_strength
    END AS opposition_attack_strength,
    CASE 
        WHEN NOT fix_2.is_home THEN fix_2.home_defence_strength
        ELSE fix_2.away_defence_strength
    END AS opposition_defence_strength
FROM fix_2
order by team_name, event_name ;

-- Now can add a windows rank function
-- Once this is added can then do a rolling average

with cte as
(WITH fix_2 AS (
    SELECT fix.*, 
           td."name" AS home_team, 
           td.strength_overall_home AS home_overall_strength,
           td.strength_attack_home AS home_attack_strength,
           td.strength_defence_home AS home_defence_strength,
           td2."name" AS away_team,
           td2.strength_overall_away AS away_overall_strength,
           td2.strength_attack_away AS away_attack_strength,
           td2.strength_defence_away AS away_defence_strength
    FROM fixtures_df fix
    JOIN teams_df td ON fix.team_h = td.id
    JOIN teams_df td2 ON fix.team_a = td2.id
)

SELECT event_name,
    CASE 
        WHEN fix_2.is_home THEN fix_2.home_team
        ELSE fix_2.away_team
    END AS team_name,
    fix_2.is_home,
    CASE 
        WHEN fix_2.is_home THEN fix_2.home_overall_strength
        ELSE fix_2.away_overall_strength
    END AS overall_strength,
    CASE 
        WHEN fix_2.is_home THEN fix_2.home_attack_strength
        ELSE fix_2.away_attack_strength
    END AS attack_strength,
    CASE 
        WHEN fix_2.is_home THEN fix_2.home_defence_strength
        ELSE fix_2.away_defence_strength
    END AS defence_strength,
    CASE 
        WHEN fix_2.is_home THEN fix_2.away_team
        ELSE fix_2.home_team
    END AS opposition_name,
    CASE 
        WHEN NOT fix_2.is_home THEN fix_2.home_overall_strength
        ELSE fix_2.away_overall_strength
    END AS opposition_overall_strength,
    CASE 
        WHEN NOT fix_2.is_home THEN fix_2.home_attack_strength
        ELSE fix_2.away_attack_strength
    END AS opposition_attack_strength,
    CASE 
        WHEN NOT fix_2.is_home THEN fix_2.home_defence_strength
        ELSE fix_2.away_defence_strength
    END AS opposition_defence_strength
FROM fix_2
order by team_name, event_name)
select CAST(event_name AS INTEGER) as GW,
team_name,
is_home,
opposition_name,
DENSE_RANK() OVER (PARTITION BY is_home ORDER BY opposition_overall_strength DESC) AS fixture_difficulty_rank_ovr,
DENSE_RANK() OVER (PARTITION BY is_home ORDER BY opposition_attack_strength DESC) AS fixture_difficulty_rank_att,
DENSE_RANK() OVER (PARTITION BY is_home ORDER BY opposition_defence_strength DESC) AS fixture_difficulty_rank_def
from cte
order by team_name, gw;

-- Can now create the rolling averages for the next 5 fixtures per team

with cte_2 as 
(with cte as
(WITH fix_2 AS (
    SELECT fix.*, 
           td."name" AS home_team, 
           td.strength_overall_home AS home_overall_strength,
           td.strength_attack_home AS home_attack_strength,
           td.strength_defence_home AS home_defence_strength,
           td2."name" AS away_team,
           td2.strength_overall_away AS away_overall_strength,
           td2.strength_attack_away AS away_attack_strength,
           td2.strength_defence_away AS away_defence_strength
    FROM fixtures_df fix
    JOIN teams_df td ON fix.team_h = td.id
    JOIN teams_df td2 ON fix.team_a = td2.id
)

SELECT event_name,
    CASE 
        WHEN fix_2.is_home THEN fix_2.home_team
        ELSE fix_2.away_team
    END AS team_name,
    fix_2.is_home,
    CASE 
        WHEN fix_2.is_home THEN fix_2.home_overall_strength
        ELSE fix_2.away_overall_strength
    END AS overall_strength,
    CASE 
        WHEN fix_2.is_home THEN fix_2.home_attack_strength
        ELSE fix_2.away_attack_strength
    END AS attack_strength,
    CASE 
        WHEN fix_2.is_home THEN fix_2.home_defence_strength
        ELSE fix_2.away_defence_strength
    END AS defence_strength,
    CASE 
        WHEN fix_2.is_home THEN fix_2.away_team
        ELSE fix_2.home_team
    END AS opposition_name,
    CASE 
        WHEN NOT fix_2.is_home THEN fix_2.home_overall_strength
        ELSE fix_2.away_overall_strength
    END AS opposition_overall_strength,
    CASE 
        WHEN NOT fix_2.is_home THEN fix_2.home_attack_strength
        ELSE fix_2.away_attack_strength
    END AS opposition_attack_strength,
    CASE 
        WHEN NOT fix_2.is_home THEN fix_2.home_defence_strength
        ELSE fix_2.away_defence_strength
    END AS opposition_defence_strength
FROM fix_2
order by team_name, event_name)
select CAST(event_name AS INTEGER) as GW,
team_name,
is_home,
opposition_name,
DENSE_RANK() OVER (PARTITION BY is_home ORDER BY opposition_overall_strength DESC) AS fixture_difficulty_rank_ovr,
DENSE_RANK() OVER (PARTITION BY is_home ORDER BY opposition_attack_strength DESC) AS fixture_difficulty_rank_att,
DENSE_RANK() OVER (PARTITION BY is_home ORDER BY opposition_defence_strength DESC) AS fixture_difficulty_rank_def
from cte
order by team_name, gw)
SELECT 
    GW,
    team_name,
    is_home,
    opposition_name,
    fixture_difficulty_rank_ovr,
    fixture_difficulty_rank_att,
    fixture_difficulty_rank_def,
    AVG(fixture_difficulty_rank_ovr) OVER (
        PARTITION BY team_name, is_home
        ORDER BY CAST(GW AS INTEGER) 
        RANGE BETWEEN CURRENT ROW AND 4 FOLLOWING
    ) AS rolling_avg_ovr,
    AVG(fixture_difficulty_rank_att) OVER (
        PARTITION BY team_name, is_home
        ORDER BY CAST(GW AS INTEGER) 
        RANGE BETWEEN CURRENT ROW AND 4 FOLLOWING
    ) AS rolling_avg_att,
    AVG(fixture_difficulty_rank_def) OVER (
        PARTITION BY team_name, is_home
        ORDER BY CAST(GW AS INTEGER) 
        RANGE BETWEEN CURRENT ROW AND 4 FOLLOWING
    ) AS rolling_avg_def
FROM cte_2
ORDER BY team_name, GW::INTEGER;

-- Creating Table

CREATE TABLE Fixture_Difficulty As
with cte_2 as 
(with cte as
(WITH fix_2 AS (
    SELECT fix.*, 
           td."name" AS home_team, 
           td.strength_overall_home AS home_overall_strength,
           td.strength_attack_home AS home_attack_strength,
           td.strength_defence_home AS home_defence_strength,
           td2."name" AS away_team,
           td2.strength_overall_away AS away_overall_strength,
           td2.strength_attack_away AS away_attack_strength,
           td2.strength_defence_away AS away_defence_strength
    FROM fixtures_df fix
    JOIN teams_df td ON fix.team_h = td.id
    JOIN teams_df td2 ON fix.team_a = td2.id
)

SELECT event_name,
    CASE 
        WHEN fix_2.is_home THEN fix_2.home_team
        ELSE fix_2.away_team
    END AS team_name,
    fix_2.is_home,
    CASE 
        WHEN fix_2.is_home THEN fix_2.home_overall_strength
        ELSE fix_2.away_overall_strength
    END AS overall_strength,
    CASE 
        WHEN fix_2.is_home THEN fix_2.home_attack_strength
        ELSE fix_2.away_attack_strength
    END AS attack_strength,
    CASE 
        WHEN fix_2.is_home THEN fix_2.home_defence_strength
        ELSE fix_2.away_defence_strength
    END AS defence_strength,
    CASE 
        WHEN fix_2.is_home THEN fix_2.away_team
        ELSE fix_2.home_team
    END AS opposition_name,
    CASE 
        WHEN NOT fix_2.is_home THEN fix_2.home_overall_strength
        ELSE fix_2.away_overall_strength
    END AS opposition_overall_strength,
    CASE 
        WHEN NOT fix_2.is_home THEN fix_2.home_attack_strength
        ELSE fix_2.away_attack_strength
    END AS opposition_attack_strength,
    CASE 
        WHEN NOT fix_2.is_home THEN fix_2.home_defence_strength
        ELSE fix_2.away_defence_strength
    END AS opposition_defence_strength
FROM fix_2
order by team_name, event_name)
select CAST(event_name AS INTEGER) as GW,
team_name,
is_home,
opposition_name,
DENSE_RANK() OVER (PARTITION BY is_home ORDER BY opposition_overall_strength DESC) AS fixture_difficulty_rank_ovr,
DENSE_RANK() OVER (PARTITION BY is_home ORDER BY opposition_attack_strength DESC) AS fixture_difficulty_rank_att,
DENSE_RANK() OVER (PARTITION BY is_home ORDER BY opposition_defence_strength DESC) AS fixture_difficulty_rank_def
from cte
order by team_name, gw)
SELECT 
    GW,
    team_name,
    is_home,
    opposition_name,
    fixture_difficulty_rank_ovr,
    fixture_difficulty_rank_att,
    fixture_difficulty_rank_def,
    AVG(fixture_difficulty_rank_ovr) OVER (
        PARTITION BY team_name, is_home
        ORDER BY CAST(GW AS INTEGER) 
        RANGE BETWEEN CURRENT ROW AND 4 FOLLOWING
    ) AS rolling_avg_ovr,
    AVG(fixture_difficulty_rank_att) OVER (
        PARTITION BY team_name, is_home
        ORDER BY CAST(GW AS INTEGER) 
        RANGE BETWEEN CURRENT ROW AND 4 FOLLOWING
    ) AS rolling_avg_att,
    AVG(fixture_difficulty_rank_def) OVER (
        PARTITION BY team_name, is_home
        ORDER BY CAST(GW AS INTEGER) 
        RANGE BETWEEN CURRENT ROW AND 4 FOLLOWING
    ) AS rolling_avg_def
FROM cte_2
ORDER BY team_name, GW::INTEGER;


select *
from fixture_difficulty
limit 5;

-- Showing teams with the easiest overall fixtures

select team_name
from fixture_difficulty fd
where GW = 12
order by rolling_avg_ovr desc 
limit 5;

-- Showing teams with best attacking fixtures

select team_name
from fixture_difficulty fd
where GW = 12
order by rolling_avg_att desc 
limit 5;

-- Showing teams with best defensive fixtures

select team_name
from fixture_difficulty fd
where GW = 12
order by rolling_avg_def desc 
limit 5;

-- Showing teams with worst fixtures

select team_name
from fixture_difficulty fd
where GW = 12
order by rolling_avg_ovr asc  
limit 5;
