# FPL_SQL_Project

Welcome to my FPL Project which looks at utilising Postgresql & Python to extract, manipulate, and analyse FPL data.

## Project Aims:

Player Performance: I began by dissecting player data, joining information from various tables, and calculating crucial performance metrics such as goals, assists, and expected goals involvement.
Team Analysis: Moving on to teams, I analyzed their overall strength, attacking prowess, and defensive capabilities. By comparing these attributes, I gained insights into team dynamics.
Fixture Difficulty: I developed a comprehensive system to assess the difficulty of upcoming fixtures. This involved considering team strengths and analyzing the challenges each team might face in their next matches.
Data Extraction with Python:
To kickstart this analysis, I wrote a Python script to extract data from the Fantasy Premier League (FPL) API. This script fetches real-time player and team data, providing a fresh and dynamic dataset for the SQL analysis.

## Outcomes:

Identified top-performing players and teams based on various metrics, shedding light on key influencers in the game.
Established correlations between expected metrics (like expected goals involvement) and actual performance, highlighting the predictive power of certain statistics.
Created a dynamic fixture difficulty ranking system, enabling users to gauge the upcoming challenges faced by different teams.
How to Use This Repository:

Data Extraction: Check out the Python script for data extraction to understand how I fetched real-time data from the FPL API, ensuring our analysis is up-to-date and accurate.
Player Performance, Team Analysis, and Fixture Difficulty: Check out the SQL script where I explore the relationships in the data. Notable insights are highlighted with the aim of providing a Tableau dashboard. The dashboard is publically available [here](https://public.tableau.com/views/FPLDashboard_16995484964890/FPLTeamAnalysis?:language=en-GB&:display_count=n&:origin=viz_share_link) and is based on created tables from the SQL code. 

