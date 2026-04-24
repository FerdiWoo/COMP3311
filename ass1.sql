-- ass1.sql
-- Your Name: Ferdinand Woo
-- Your Student ID: z5350438

----------------------------------------------------------------
-- Q1: SQL function goals_in_match (define before Q5/Q7 if you use it there)
-- up_to_minute: default 90 = full-time; pass 85 for score at minute 85
DROP FUNCTION IF EXISTS goals_in_match(INTEGER, BOOLEAN, INTEGER) CASCADE;
CREATE OR REPLACE FUNCTION goals_in_match(match_id INTEGER, _is_home BOOLEAN, up_to_minute INTEGER DEFAULT 90)
RETURNS INTEGER AS $$
    SELECT count(*)::integer
    FROM goals g
    JOIN players p ON p.id=g.scored_by
    JOIN teams t ON t.id=p.member_of
    JOIN involves i ON i.team=t.id
    	AND g.scored_in=i.match
    WHERE g.scored_in=goals_in_match.match_id
	AND i.is_home=goals_in_match._is_home
	AND g.time_scored <= goals_in_match.up_to_minute
    ;  -- replace: count goals where involves.is_home = _is_home and time_scored <= up_to_minute
$$ LANGUAGE SQL;

----------------------------------------------------------------
CREATE OR REPLACE VIEW Q2(team, country, total_goals) AS
WITH Totals AS (
    SELECT t.id, t.country, COUNT(*)::INTEGER as goals
    FROM teams t
    JOIN players p ON t.id = p.member_of
    JOIN goals g ON p.id = g.scored_by
    GROUP BY t.id, t.country
)
SELECT id, country, goals
FROM Totals
WHERE goals = (SELECT MAX(goals) FROM Totals)
ORDER BY id ASC;


----------------------------------------------------------------
CREATE OR REPLACE VIEW Q3(match_id, player_id, player, first_half_goals, second_half_goals) AS (
    SELECT 
    	g.scored_in AS match_id,
    	p.id AS player_id,
    	p.name AS player,
    	SUM(CASE WHEN g.time_scored <= 45 THEN 1 ELSE 0 END) AS first_half_goals,
    	SUM(CASE WHEN g.time_scored > 45 THEN 1 ELSE 0 END) AS second_half_goals 
    FROM 	matches m 
    JOIN 	goals g ON g.scored_in=m.id 
    JOIN 	players p ON p.id=g.scored_by 
    GROUP BY 	p.id, p.name,g.scored_in 
    HAVING 	SUM(CASE WHEN g.time_scored <= 45 THEN 1 ELSE 0 END) >= 1 
    		AND SUM(CASE WHEN g.time_scored > 45 THEN 1 ELSE 0 END) >=1 
    ORDER BY 	g.scored_in, p.id
);

----------------------------------------------------------------
CREATE OR REPLACE VIEW Q4(team, country, yellow_cards, red_cards, discipline_score) AS (
	SELECT 
		t.id AS team,
		t.country AS country, 
		SUM(CASE WHEN c.card_type = 'yellow' THEN 1 ELSE 0 END) AS yellow_cards, 
		SUM(CASE WHEN c.card_type = 'red' THEN 1 ELSE 0 END) red_cards,
		(SUM(CASE WHEN c.card_type = 'yellow' THEN 1 ELSE 0 END) * 2) + 
		(SUM(CASE WHEN c.card_type = 'red' THEN 1 ELSE 0 END) * 5) AS discipline_score 
	FROM 		cards c JOIN players p ON c.given_to=p.id 
	JOIN 		teams t ON t.id=p.member_of 
	GROUP BY 	t.id, t.country 
	HAVING 		COUNT(*) >= 6 
	ORDER BY 	discipline_score DESC, t.id ASC
);

----------------------------------------------------------------
CREATE OR REPLACE VIEW Q5(match_id, city, winner, loser, score) AS 
WITH MatchDetails AS (
	SELECT	m.id AS match_id,
		m.city AS city,
		t_home.country AS t_home_country,
		t_away.country AS t_away_country,
		goals_in_match(m.id, TRUE) as t_home_score ,
		goals_in_match(m.id, FALSE) as t_away_score
	FROM	matches m
	JOIN 	involves i_home ON m.id=i_home.match AND i_home.is_home=TRUE
	JOIN	involves i_away ON m.id=i_away.match AND i_away.is_home=FALSE
	JOIN	teams t_home ON t_home.id=i_home.team
	JOIN	teams t_away ON t_away.id=i_away.team	
)
	SELECT	match_id,
		city,
		CASE WHEN t_home_score > t_away_score THEN t_home_country ELSE t_away_country END,
		CASE WHEN t_home_score < t_away_score THEN t_home_country ELSE t_away_country END,
		t_home_score || '-' || t_away_score
	FROM	matchDetails
	WHERE	(t_home_score = 0 or t_away_score = 0) AND (t_home_score >=3 or t_away_score >= 3)
	ORDER BY	CASE WHEN t_home_score > t_away_score THEN t_home_score ELSE t_away_score END DESC, match_id ASC; 		

----------------------------------------------------------------
CREATE OR REPLACE VIEW AllTeamStats AS (
    SELECT		t.id as team,
				t.country AS country,
				COUNT ( DISTINCT i.match) as matches_played, 
				SUM(CASE
					WHEN i.is_home THEN goals_in_match(i.match, TRUE) 
					ELSE goals_in_match(i.match, FALSE) END) AS goals_scored,
				SUM(CASE 
					WHEN i.is_home THEN goals_in_match(i.match, FALSE)
					ELSE goals_in_match(i.match, TRUE) END) AS goals_conceeded			
	FROM	 	teams t
	JOIN		involves i ON i.team=t.id
	GROUP BY	t.id,t.country
);

CREATE OR REPLACE VIEW Q6 (team, country, matches_played, goal_diff) AS 
WITH CalculatedDiff AS(
	SELECT	team,
			country,
			matches_played,
			(goals_scored - goals_conceeded) AS goal_diff
	FROM 	AllTeamStats
	WHERE	matches_played >= 50
)
SELECT 		* 
FROM 		CalculatedDiff
WHERE		goal_diff = (SELECT MAX(goal_diff) FROM CalculatedDiff)
ORDER BY	team ASC;

----------------------------------------------------------------
CREATE OR REPLACE VIEW Q7(match_id, city, winning_team, losing_team, score_85, fulltime_score) AS
WITH TimedGoalStats AS (
    SELECT		m.id AS match_id,
				m.city AS city,
				goals_in_match(m.id, TRUE, 85) AS t_home_score_85,
				goals_in_match(m.id, FALSE, 85) AS t_away_score_85,
				goals_in_match(m.id, TRUE) AS t_home_score_90,
				goals_in_match(m.id, FALSE) AS t_away_score_90,
				t_home.country AS home_country,
				t_away.country AS away_country
	FROM 		matches m
	JOIN 		involves i_home ON i_home.match=m.id AND i_home.is_home=TRUE
	JOIN 		involves i_away ON i_away.match=m.id AND i_away.is_home=FALSE
	JOIN 		teams t_home ON t_home.id=i_home.team 
	JOIN		teams t_away ON t_away.id=i_away.team
)
SELECT 		match_id,
			city,
			CASE WHEN t_home_score_90 > t_away_score_90 THEN home_country ELSE away_country END,
			CASE WHEN t_home_score_90 < t_away_score_90 THEN home_country ELSE away_country END,
			t_home_score_85 || '-' || t_away_score_85,
			t_home_score_90 || '-' || t_away_score_90
FROM 		TimedGoalStats
WHERE		t_home_score_85 = t_away_score_85 AND t_home_score_90 != t_away_score_90
ORDER BY 	match_id ASC;


----------------------------------------------------------------
CREATE OR REPLACE VIEW Q8(match_id, red_team, red_minute, score, goals_after_red) AS 
WITH 
FirstRed AS (
SELECT		DISTINCT ON (given_in)
		id AS card_id,
		given_in,
		time_given,
		given_to
FROM 		cards
WHERE		card_type = 'red'
ORDER BY	given_in, time_given ASC, id ASC 
),

GoalStats AS(
SELECT		m.id as match_id,
		CASE
			WHEN p.member_of = i_home.team THEN t_home.country ELSE t_away.country END AS red_team_name,
    		t_home.country as home_country,
    		t_away.country as away_country,
    		c.time_given as red_minute,
    		goals_in_match(m.id, TRUE, c.time_given) AS t_home_score_red,
		goals_in_match(m.id, FALSE, c.time_given) AS t_away_score_red,	    		
    		goals_in_match(m.id, TRUE) AS t_home_score_90,
		goals_in_match(m.id, FALSE) AS t_away_score_90,
		c.given_to as c_given_to,
		c.time_given as c_time_given
FROM 		matches m
JOIN 		involves i_home ON i_home.match=m.id AND i_home.is_home=TRUE
JOIN 		involves i_away ON i_away.match=m.id AND i_away.is_home=FALSE
JOIN 		teams t_home ON t_home.id=i_home.team 
JOIN		teams t_away ON t_away.id=i_away.team	
JOIN		FirstRed c ON c.given_in=m.id
JOIN		players p ON p.id=c.given_to
)
SELECT   	match_id,
		red_team_name,
		c_time_given,
		t_home_score_90 || '-' || t_away_score_90,
		(t_home_score_90 - t_home_score_red) + (t_away_score_90 - t_away_score_red)
FROM 		GoalStats
WHERE 		(t_home_score_90 - t_home_score_red) + (t_away_score_90 - t_away_score_red) >= 2
ORDER BY	((t_home_score_90 - t_home_score_red) + (t_away_score_90 - t_away_score_red)) DESC, match_id ASC;

----------------------------------------------------------------
-- Q9: SQL function (LANGUAGE sql; body = single SELECT returning set of TEXT)
DROP FUNCTION IF EXISTS Q9(pattern TEXT);
CREATE OR REPLACE FUNCTION Q9(pattern TEXT)
RETURNS SETOF TEXT AS $$
    SELECT 
        team || ' | ' || 
        country || ' | ' || 
        matches_played || ' | ' || 
        goals_scored || ' | ' || 
        goals_conceeded || ' | ' || 
        (goals_scored - goals_conceeded)
    FROM 
        AllTeamStats
    WHERE
        country ILIKE '%' || pattern || '%'
    ORDER BY 
        (goals_scored - goals_conceeded) DESC, 
        team ASC;
$$ LANGUAGE SQL;

----------------------------------------------------------------
-- Q10: PLpgSQL function Q10(t) — team summary
DROP FUNCTION IF EXISTS Q10(t INTEGER);
CREATE OR REPLACE FUNCTION Q10(t INTEGER)
RETURNS TEXT AS $$
    DECLARE
        result_text TEXT := '';
        v_country TEXT;
        v_mp INT := 0; v_w INT := 0; v_d INT := 0; v_l INT := 0; 
        v_gf INT := 0; v_ga INT := 0; v_gd INT := 0;
        v_opp_country TEXT; v_opp_id INT; v_opp_matches INT := 0;
        scorer_rec RECORD;
        scorer_count INT := 0;
    BEGIN
        SELECT country INTO v_country FROM teams WHERE id = t;
        
        IF NOT FOUND THEN
            RETURN 'Team ID ' || t || ' not found.';
        END IF;

        SELECT 
            COUNT(match),
            COALESCE(SUM(CASE WHEN my_goals > opp_goals THEN 1 ELSE 0 END), 0),
            COALESCE(SUM(CASE WHEN my_goals = opp_goals THEN 1 ELSE 0 END), 0),
            COALESCE(SUM(CASE WHEN my_goals < opp_goals THEN 1 ELSE 0 END), 0),
            COALESCE(SUM(my_goals), 0),
            COALESCE(SUM(opp_goals), 0)
        INTO v_mp, v_w, v_d, v_l, v_gf, v_ga
        FROM (
            SELECT 
                i1.match,
                goals_in_match(i1.match, i1.is_home) AS my_goals,
                goals_in_match(i1.match, NOT i1.is_home) AS opp_goals
            FROM involves i1
            WHERE i1.team = t
        ) AS stats;

        v_gd := v_gf - v_ga;

        SELECT t2.country, t2.id, COUNT(i2.match) AS n_matches
        INTO v_opp_country, v_opp_id, v_opp_matches
        FROM involves i1
        JOIN involves i2 ON i1.match = i2.match AND i1.team <> i2.team
        JOIN teams t2 ON i2.team = t2.id
        WHERE i1.team = t
        GROUP BY t2.id, t2.country
        ORDER BY n_matches DESC, t2.id ASC
        LIMIT 1;

        result_text := 'Team ' || t || ': ' || v_country || chr(10);
        result_text := result_text || 'Matches: ' || v_mp || ' | Wins: ' || v_w || ' | Draws: ' || v_d || ' | Losses: ' || v_l || chr(10);
        result_text := result_text || 'Goals: ' || v_gf || '-' || v_ga || ' (GD=' || v_gd || ')' || chr(10);
        
        IF v_opp_country IS NOT NULL THEN
            result_text := result_text || 'Most frequent opponent: ' || v_opp_country || ' (Team ' || v_opp_id || ') - ' || v_opp_matches || ' matches' || chr(10);
        END IF;
        
        result_text := result_text || 'Top scorers:';

        FOR scorer_rec IN (
            SELECT p.name, p.position, COUNT(g.id) AS goals
            FROM players p
            JOIN goals g ON p.id = g.scored_by
            WHERE p.member_of = t
            GROUP BY p.id, p.name, p.position
            HAVING COUNT(g.id) > 0
            ORDER BY goals DESC, p.name ASC, p.id ASC
            LIMIT 5
        ) LOOP
            result_text := result_text || chr(10) || '- ' || scorer_rec.name || ' (' || scorer_rec.position || ') : ' || scorer_rec.goals;
            scorer_count := scorer_count + 1;
        END LOOP;

        IF scorer_count = 0 THEN
            result_text := result_text || chr(10) || '- None';
        END IF;

        RETURN result_text;
    END;
$$ LANGUAGE PLpgSQL;

----------------------------------------------------------------
-- End of template
----------------------------------------------------------------
