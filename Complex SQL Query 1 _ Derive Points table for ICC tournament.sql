--create table icc_world_cup
--(
--Team_1 Varchar(20),
--Team_2 Varchar(20),
--Winner Varchar(20)
--);
--INSERT INTO icc_world_cup values('India','SL','India');
--INSERT INTO icc_world_cup values('SL','Aus','Aus');
--INSERT INTO icc_world_cup values('SA','Eng','Eng');
--INSERT INTO icc_world_cup values('Eng','NZ','NZ');
--INSERT INTO icc_world_cup values('Aus','India','India');
SELECT *
FROM   icc_world_cup;

WITH     winner_team
AS       (SELECT DISTINCT Team_1 AS team_Name,
                          CASE WHEN winner = Team_1 THEN 'winner' ELSE 'loser' END AS Match_status
          FROM   icc_world_cup
          UNION ALL
          SELECT DISTINCT Team_2 AS team_Name,
                          CASE WHEN winner = Team_2 THEN 'winner' ELSE 'loser' END AS Match_status
          FROM   icc_world_cup)
SELECT   team_Name,
         Count(team_Name) AS numof_match,
         Sum(CASE WHEN Match_status = 'winner' THEN 1 ELSE 0 END) AS noof_winner,
         sum(CASE WHEN Match_status = 'loser' THEN 1 ELSE 0 END) AS noof_loser
FROM     winner_team
GROUP BY team_Name
ORDER BY team_Name;