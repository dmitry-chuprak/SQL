/* 1.
Find the amount of questions which got over 300 points and were at least 100 times added to favorites
*/ 

SELECT COUNT(*)
FROM stackoverflow.posts AS p
LEFT JOIN stackoverflow.post_types AS pt ON p.post_type_id = pt.id
WHERE (p.score > 300
       OR p.favorites_count >= 100)
  AND TYPE = 'Question'


/* 2.
How many times on average per day questions were asked duting 1-18 Nov 2008? Round to int
*/ 

SELECT ROUND(AVG(COUNT), 0)
FROM
  (SELECT COUNT(creation_date)
   FROM stackoverflow.posts
   WHERE post_type_id = 1
     AND creation_date::date BETWEEN '2008-11-01' AND '2008-11-18'
   GROUP BY creation_date::date) AS COUNT


/* 3.
How many unique users got a badge at the registration
*/

SELECT COUNT(DISTINCT u.id)
FROM stackoverflow.users AS u
INNER JOIN stackoverflow.badges AS b ON u.id = b.user_id
WHERE u.creation_date::date = b.creation_date::date


/* 4.
How many unique posts were made by Joel Coehoorn which received at least 1 vote
*/

-- collecting friends posts

SELECT COUNT(DISTINCT id)
FROM stackoverflow.posts
WHERE user_id = 
-- searching for 'Joel Coehoorn'
    (SELECT id
     FROM stackoverflow.users AS u
     WHERE display_name = 'Joel Coehoorn')
  AND id IN
    (SELECT post_id
     FROM stackoverflow.votes)


/* 5.
Show all fields of `vote_types` table. 
Add `rank` field with all the records in reverse order. Table should be sorted by `id`
*/

SELECT *,
       ROW_NUMBER() OVER (ORDER BY id DESC) AS rank
FROM stackoverflow.vote_types
ORDER BY id


/* 6.
Pick 10 users who voted the most with type `close`. 
Show table with 2 fields: user id and number of votes. 
Sort data by "votes" descending then by "id" descending
*/

SELECT user_id,
       votes
FROM
    (-- picking all the users, assigning rang
    SELECT user_id,
           COUNT(id) as votes,
           ROW_NUMBER() OVER (ORDER BY COUNT(id) DESC) as rang
    FROM stackoverflow.votes
    WHERE vote_type_id =
    -- filtering by type 'Close'
        (SELECT id
       	FROM stackoverflow.vote_types
        WHERE name = 'Close')

    GROUP BY user_id
    ORDER BY COUNT(id) DESC) as list
WHERE rang <= 10
ORDER BY votes DESC, user_id DESC


/* 7.
Pick top-10 users by amount of badges received during 15 Nov - 15 Dec 2018 (incl).
Fields to show:
 - user id;
 - amount of badges;
 - place in rating (the more badges - the higher rating).

Users who get the same amount of badges should have the same place in rating.
Sort by badges descending, then by user id ascending
*/

SELECT user_id, badges_amt, rang
FROM
    (SELECT user_id,
           COUNT(id) as badges_amt,
           DENSE_RANK(*) OVER(ORDER BY COUNT(id) DESC) as rang,
           ROW_NUMBER() OVER(ORDER BY COUNT(id) DESC) as row_num
    FROM stackoverflow.badges
    WHERE creation_date::date BETWEEN '2008-11-15' AND '2008-12-15'
    GROUP BY user_id
    ORDER BY COUNT(id) DESC) AS badges_top
WHERE row_num <= 10
ORDER BY badges_amt DESC, user_id


/* 8.
How many scores on average each user post gets?
Fields to show:
 - post title;
 - user id
 - post score
 - average user score per post (rounded to int)
 Posts without title and with zero score should be excluded
 */

SELECT title,
       user_id,
       score,
       ROUND(AVG(score) OVER (PARTITION BY user_id), 0)
FROM stackoverflow.posts
WHERE title IS NOT NULL AND score != 0


/* 9.
Show post title written by users who got 1000+ badges
Posts without title should be excluded
*/


SELECT title
FROM stackoverflow.posts
WHERE user_id IN
    (SELECT user_id
    FROM stackoverflow.badges
    GROUP BY user_id
    HAVING COUNT(id) > 1000)
    AND title IS NOT NULL


/* 10.
Write the request which shows user details from USA ('United States'). 
Divide users in 3 groups by profile views:
- group 1: >= 350 views
- group 2: >= 100 views, < 350 views
- group 3: <100 views
Fields to show:
- user id
- number of views
- group number
Users with zero views should be out of scope
*/

SELECT id,
       views,
       CASE
           WHEN views >= 350 THEN 1
           WHEN views >= 100 THEN 2
       ELSE 3
       END AS group
FROM stackoverflow.users
WHERE location LIKE '%United States%' and views != 0


/* 11.
Extend the previous request: 
- Show each group leaders (max score in each group). 
- Show fields with user id, group, number of views
- Sort by views descending, user id ascending
*/

WITH table_ AS
(SELECT id,
     views,
     CASE
         WHEN views >= 350 THEN 1
         WHEN views >= 100 THEN 2
     ELSE 3
     END AS group_case
 FROM stackoverflow.users
 WHERE location LIKE '%United States%' and views != 0),
 
short_table AS
(SELECT *,
        RANK() OVER (PARTITION BY group_case ORDER BY views DESC)
 FROM table_)

SELECT id, group_case, views
FROM short_table
WHERE rank = 1
ORDER BY views DESC, id


/* 12.
Calculate daily new users growth in november 2008. 
Table to show:
- day number
- number of users registered in that day
- sum of users cumulative
*/ 

SELECT EXTRACT(DAY FROM DATE_TRUNC('day', creation_date)) AS reg_date,
       COUNT(id) AS new_users,
       SUM(COUNT(id)) OVER (ORDER BY EXTRACT(DAY FROM DATE_TRUNC('day', creation_date))) AS total
FROM stackoverflow.users
WHERE DATE_TRUNC('month', creation_date)::date = '2008-11-01'
GROUP BY EXTRACT(DAY FROM DATE_TRUNC('day', creation_date))


/* 13.
For each user who wrote at least one post, find the inverval between registration date and first post creation date
Show:
- user id
- time interval between registration date and first post creation date
*/

WITH first_post AS
(SELECT DISTINCT 
       user_id,
       FIRST_VALUE(creation_date) OVER (PARTITION BY user_id ORDER BY creation_date) AS first_post
FROM stackoverflow.posts)

SELECT id,
       first_post - creation_date
FROM stackoverflow.users AS u
INNER JOIN first_post AS p ON u.id = p.user_id


/* 14.
Show total amount of post views for each month in 2008
If there is no data for a specific month - this month may be missed
Sort by total views descending
*/

WITH view AS
(SELECT DISTINCT DATE_TRUNC('month', creation_date)::date,
       SUM(views_count) OVER (PARTITION BY DATE_TRUNC('month', creation_date)::date)
FROM stackoverflow.posts
WHERE DATE_TRUNC('year', creation_date)::date = '2008-01-01')

SELECT *
FROM view
ORDER BY sum DESC


/* 15.
Show the names of the most active users in the first month after registration (incl this day) who gave more than 100 answers
Questions of these users should not be counted
For each user name show unique user_id
Sort by name
*/

SELECT u.display_name,
       COUNT(DISTINCT p.user_id)
FROM stackoverflow.posts AS p
JOIN stackoverflow.users AS u ON p.user_id=u.id
JOIN stackoverflow.post_types AS pt ON pt.id=p.post_type_id
WHERE p.creation_date::date BETWEEN u.creation_date::date AND (u.creation_date::date + INTERVAL '1 month') 
      AND pt.type LIKE '%Answer%'
GROUP BY u.display_name
HAVING COUNT(p.id) > 100
ORDER BY u.display_name;


/* 16.
Show the amount of posts for 2008 by months
Pick posts of users, who registered in Sep 2018 and made at least one post in Dec 2018
Sort by month descending
*/

WITH pu AS
    (SELECT DISTINCT u.id
    FROM stackoverflow.users AS u
    JOIN stackoverflow.posts AS p ON u.id = p.user_id
    WHERE DATE_TRUNC('month', u.creation_date) = '2008-09-01'
          AND DATE_TRUNC('month', p.creation_date) = '2008-12-01')

SELECT DATE_TRUNC('month', pp.creation_date)::date,
       COUNT('id')
FROM stackoverflow.posts AS pp
INNER JOIN pu ON pp.user_id = pu.id
WHERE DATE_TRUNC('year', pp.creation_date) = '2008-01-01'
GROUP BY DATE_TRUNC('month', pp.creation_date)::date
ORDER BY DATE_TRUNC('month', pp.creation_date)::date DESC


/* 17.
Using data about posts show the following fields:
- user_id who wrote a post
- post creation date
- number of views of this post
- cumulative amount of views of this author
Data should be sorted by user_id, data of each user - by data creation date ascending
*/

SELECT user_id,
       creation_date,
       views_count,
       SUM(views_count) OVER (PARTITION BY user_id ORDER BY creation_date)
FROM stackoverflow.posts
ORDER BY user_id, creation_date


/* 18.
How many days in average during 1-7 Dec 2008 (incl) users interact with platform?
For each users need to show days when they posted at least once
Result should be rounded to integer
*/

WITH activity AS
(SELECT COUNT(DISTINCT DATE_TRUNC('day', creation_date))
FROM stackoverflow.posts
WHERE DATE_TRUNC('day', creation_date) BETWEEN '2008-12-01' AND '2008-12-7'
GROUP BY user_id)

SELECT ROUND(AVG(COUNT), 0)
FROM activity


/* 19.
How much is the % change between amount of post from 1 Sep to 31 Dec 2008?
Show the following table:
- month number
- number of posts for a month
- % which shows the amount posts change in current month vs previous
If number of posts decreased - the % should be negative. If not - positive
Round up to 2 points after coma (in PostgreSQL it's better to change the dividend to `numeric`)
*/

SELECT EXTRACT(MONTH FROM DATE_TRUNC('month', creation_date)) AS month_num,
       COUNT(id) as post_count,
       ROUND(COUNT(id) *100.0 / LAG(COUNt(id)) OVER () - 100, 2)
FROM stackoverflow.posts
WHERE DATE_TRUNC('day', creation_date) BETWEEN '2008-09-01' AND '2008-12-31'
GROUP BY EXTRACT(MONTH FROM DATE_TRUNC('month', creation_date))


/* 20.
Get user details of the users who made the biggest amount of posts of all time
Show the data for Oct 2008 in the following view:
- week number
- date and time of the last post published this week
*/

WITH user_post AS
    (SELECT user_id,
           COUNT(id),
           ROW_NUMBER() OVER(ORDER BY COUNT(id) DESC)
    FROM stackoverflow.posts
    GROUP BY user_id
    ORDER BY count DESC)

SELECT DISTINCT EXTRACT(WEEK FROM DATE_TRUNC('week', creation_date)::date),
       LAST_VALUE(creation_date) OVER (PARTITION BY DATE_TRUNC('week', creation_date))
FROM stackoverflow.posts
WHERE user_id IN     
    (SELECT user_id
    FROM user_post
    WHERE row_number = 1)
    AND DATE_TRUNC('month', creation_date) = '2008-10-01'
