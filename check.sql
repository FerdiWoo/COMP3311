BEGIN;

\echo 'Checking Q1 (goals_in_match) ...'
SELECT CASE WHEN goals_in_match(110, true, 90) = 2 AND goals_in_match(3, true, 90) = 0
  AND goals_in_match(382, true, 85) = 2 AND goals_in_match(382, true, 90) = 3
  THEN 'Q1 PASS' ELSE 'Q1 FAIL' END AS result;

\echo 'Checking Q2 ...'
WITH expected(team,country,total_goals) AS (
  VALUES
    (10, 'Japan', 74),
    (14, 'Sweden', 74)
)
SELECT CASE WHEN EXISTS (
  (SELECT * FROM Q2 EXCEPT SELECT * FROM expected)
  UNION
  (SELECT * FROM expected EXCEPT SELECT * FROM Q2)
) THEN 'Q2 FAIL' ELSE 'Q2 PASS' END AS result;

\echo 'Checking Q3 ...'
WITH expected(match_id,player_id,player,first_half_goals,second_half_goals) AS (
  VALUES
    (116, 73, 'Marcello Carlos', 1, 1),
    (141, 115, 'Jun Li', 1, 1),
    (151, 206, 'Klaus Linke', 1, 1),
    (163, 9, 'Manuel Lopez', 1, 1),
    (192, 440, 'Pedro Suarez', 1, 1),
    (465, 107, 'Jun Wang', 1, 1)
)
SELECT CASE WHEN EXISTS (
  (SELECT * FROM Q3 EXCEPT SELECT * FROM expected)
  UNION
  (SELECT * FROM expected EXCEPT SELECT * FROM Q3)
) THEN 'Q3 FAIL' ELSE 'Q3 PASS' END AS result;

\echo 'Checking Q4 ...'
WITH expected(team,country,yellow_cards,red_cards,discipline_score) AS (
  VALUES
    (13, 'Spain', 7, 7, 49),
    (10, 'Japan', 2, 7, 39),
    (5, 'England', 4, 4, 28),
    (15, 'Uruguay', 8, 2, 26),
    (6, 'France', 12, 0, 24),
    (7, 'Germany', 7, 1, 19),
    (14, 'Sweden', 7, 1, 19),
    (2, 'Australia', 6, 1, 17),
    (9, 'Iran', 6, 1, 17),
    (11, 'Korea', 5, 1, 15)
)
SELECT CASE WHEN EXISTS (
  (SELECT * FROM Q4 EXCEPT SELECT * FROM expected)
  UNION
  (SELECT * FROM expected EXCEPT SELECT * FROM Q4)
) THEN 'Q4 FAIL' ELSE 'Q4 PASS' END AS result;

\echo 'Checking Q5 ...'
WITH expected(match_id,city,winner,loser,score) AS (
  VALUES
    (343, 'Busan', 'Korea', 'Argentina', '4-0'),
    (105, 'Linkoping', 'Sweden', 'Argentina', '3-0'),
    (107, 'Lyon', 'France', 'Uruguay', '3-0'),
    (116, 'Marseille', 'Brazil', 'France', '0-3'),
    (163, 'Santa Cruz', 'Argentina', 'France', '3-0'),
    (312, 'Santa Cruz', 'Argentina', 'Brazil', '3-0'),
    (337, 'Rio de Janiero', 'China', 'Brazil', '0-3'),
    (354, 'Seoul', 'Uruguay', 'Korea', '0-3'),
    (466, 'Shanghai', 'China', 'Iran', '3-0')
)
SELECT CASE WHEN EXISTS (
  (SELECT * FROM Q5 EXCEPT SELECT * FROM expected)
  UNION
  (SELECT * FROM expected EXCEPT SELECT * FROM Q5)
) THEN 'Q5 FAIL' ELSE 'Q5 PASS' END AS result;

\echo 'Checking Q6 ...'
WITH expected(team,country,matches_played,goal_diff) AS (
  VALUES
    (4, 'China', 53, 12),
    (7, 'Germany', 56, 12)
)
SELECT CASE WHEN EXISTS (
  (SELECT * FROM Q6 EXCEPT SELECT * FROM expected)
  UNION
  (SELECT * FROM expected EXCEPT SELECT * FROM Q6)
) THEN 'Q6 FAIL' ELSE 'Q6 PASS' END AS result;

\echo 'Checking Q7 ...'
WITH expected(match_id,city,winning_team,losing_team,score_85,fulltime_score) AS (
  VALUES
    (131, 'Melbourne', 'Australia', 'Spain', '1-1', '2-1'),
    (136, 'Rio de Janiero', 'Brazil', 'China', '0-0', '1-0'),
    (220, 'Brisbane', 'Australia', 'France', '0-0', '1-0'),
    (281, 'Marseille', 'Uruguay', 'France', '1-1', '1-2'),
    (314, 'Madrid', 'Uruguay', 'Spain', '1-1', '1-2'),
    (325, 'Stockholm', 'Japan', 'Sweden', '0-0', '0-1'),
    (382, 'Sydney', 'Australia', 'Brazil', '2-2', '3-2'),
    (423, 'Sao Paulo', 'Brazil', 'Germany', '0-0', '1-0')
)
SELECT CASE WHEN EXISTS (
  (SELECT * FROM Q7 EXCEPT SELECT * FROM expected)
  UNION
  (SELECT * FROM expected EXCEPT SELECT * FROM Q7)
) THEN 'Q7 FAIL' ELSE 'Q7 PASS' END AS result;

\echo 'Checking Q8 ...'
WITH expected(match_id,red_team,red_minute,score,goals_after_red) AS (
  VALUES
    (106, 'Japan', 41, '1-4', 3),
    (170, 'Spain', 52, '2-3', 3),
    (132, 'England', 60, '2-0', 2),
    (146, 'Spain', 78, '2-0', 2),
    (181, 'Germany', 29, '1-2', 2),
    (397, 'Japan', 71, '1-2', 2),
    (439, 'Italy', 17, '2-0', 2)
)
SELECT CASE WHEN EXISTS (
  (SELECT * FROM Q8 EXCEPT SELECT * FROM expected)
  UNION
  (SELECT * FROM expected EXCEPT SELECT * FROM Q8)
) THEN 'Q8 FAIL' ELSE 'Q8 PASS' END AS result;

\echo 'Checking Q9 ...'
WITH expected(line) AS (
  VALUES
    ('7 | Germany | 56 | 68 | 56 | 12'),
    ('5 | England | 48 | 58 | 52 | 6'),
    ('10 | Japan | 61 | 74 | 71 | 3'),
    ('6 | France | 52 | 57 | 67 | -10'),
    ('12 | Netherlands | 53 | 51 | 63 | -12'),
    ('9 | Iran | 49 | 49 | 64 | -15')
)
SELECT CASE WHEN EXISTS (
  (SELECT * FROM Q9('an') EXCEPT SELECT * FROM expected)
  UNION
  (SELECT * FROM expected EXCEPT SELECT * FROM Q9('an'))
) THEN 'Q9a FAIL' ELSE 'Q9a PASS' END AS result;

\echo 'Checking Q9 (no match) ...'
SELECT CASE WHEN EXISTS(SELECT Q9('zzz'))
            THEN 'Q9b FAIL'
            ELSE 'Q9b PASS'
       END AS result;

\echo 'Checking Q10(2) ...'
WITH expected_q10a(val) AS (
  VALUES ($$
Team 2: Australia                                   
Matches: 50 | Wins: 17 | Draws: 16 | Losses: 17     
Goals: 53-51 (GD=2)                                 
Most frequent opponent: Sweden (Team 14) - 6 matches
Top scorers:                                        
- Dave Smith (forward) : 5                          
- Harry Kewell (defender) : 4                        
- Bill Jones (forward) : 3                          
- Bill Kewell (defender) : 3                        
- Bruce Muscat (defender) : 3                       
$$)
),
normed_q10a AS (
  SELECT regexp_replace(val, E'\\s+', '', 'g') AS expected_norm,
         regexp_replace(Q10(2), E'\\s+', '', 'g') AS got_norm
  FROM expected_q10a
)
SELECT CASE WHEN expected_norm = got_norm THEN 'Q10a PASS' ELSE 'Q10a FAIL' END AS result
FROM normed_q10a;

\echo 'Checking Q10(7) ...'
WITH expected_q10b(val) AS (
  VALUES ($$
Team 7: Germany
Matches: 56 | Wins: 23 | Draws: 16 | Losses: 17
Goals: 68-56 (GD=12)
Most frequent opponent: France (Team 6) - 9 matches
Top scorers:
- Michael Baumann (forward) : 8
- Christian Baumann (midfield) : 5
- Hans Linke (forward) : 5
- Christian Boehme (defender) : 4
- Hans Baumann (forward) : 4
$$)
),
normed_q10b AS (
  SELECT regexp_replace(val, E'\\s+', '', 'g') AS expected_norm,
         regexp_replace(Q10(7), E'\\s+', '', 'g') AS got_norm
  FROM expected_q10b
)
SELECT CASE WHEN expected_norm = got_norm THEN 'Q10b PASS' ELSE 'Q10b FAIL' END AS result
FROM normed_q10b;

\echo 'Checking Q10(99) ...'
WITH expected_q10c(val) AS (
  VALUES ($$Team ID 99 not found.$$)
),
normed_q10c AS (
  SELECT regexp_replace(val, E'\\s+', '', 'g') AS expected_norm,
         regexp_replace(Q10(99), E'\\s+', '', 'g') AS got_norm
  FROM expected_q10c
)
SELECT CASE WHEN expected_norm = got_norm THEN 'Q10c PASS' ELSE 'Q10c FAIL' END AS result
FROM normed_q10c;

COMMIT;
\echo '----------------- Checking complete -----------------'
