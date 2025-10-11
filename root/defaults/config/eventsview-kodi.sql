CREATE VIEW eventsview AS
WITH ShortTextFormatter AS (
  -- CTE to format the main shorttext part
  SELECT
    cnt_useid,
    cnt_eventid,
    CONCAT(
      CASE WHEN LENGTH(IFNULL(sub_category,'')) > 0 THEN sub_category ELSE '' END,
      CASE WHEN LENGTH(IFNULL(sub_category,'')) > 0 AND LENGTH(IFNULL(sub_genre,'')) > 0 THEN ' - ' ELSE '' END,
      CASE WHEN LENGTH(IFNULL(sub_genre,'')) > 0 THEN sub_genre ELSE '' END,
      CASE WHEN LENGTH(IFNULL(sub_genre,'')) > 0 AND LENGTH(IFNULL(sub_country,'')) + LENGTH(IFNULL(sub_year,'')) > 0 THEN ' (' ELSE '' END,
      CASE WHEN LENGTH(IFNULL(sub_country,'')) > 0 THEN sub_country ELSE '' END,
      CASE WHEN LENGTH(IFNULL(sub_country,'')) > 0 AND LENGTH(IFNULL(sub_year,'')) > 0 THEN ' ' ELSE '' END,
      CASE WHEN LENGTH(IFNULL(sub_year,'')) > 0 THEN sub_year ELSE '' END,
      CASE WHEN LENGTH(IFNULL(sub_genre,'')) > 0 AND LENGTH(IFNULL(sub_country,'')) + LENGTH(IFNULL(sub_year,'')) > 0 THEN ')' ELSE '' END
    ) AS formatted_shorttext_part
  FROM useevents
),
DescriptionPart1 AS (
  -- CTE for the first part of the description (short descriptions, rating)
  SELECT
    u.cnt_useid,
    u.cnt_eventid,
    -- Refactored to use CONCAT_WS with two groups to handle blank lines.
    CONCAT_WS('||',
      -- Group I: shortdescription and shortreview
      CASE WHEN LENGTH(TRIM(CONCAT_WS('|', u.sub_shortdescription, u.sub_shortreview))) > 0
      THEN CONCAT_WS('|',
           u.sub_shortdescription,
           u.sub_shortreview
         )
      ELSE NULL
    END,
      -- Group II: tipp, txtrating, and rating
      CASE WHEN LENGTH(TRIM(CONCAT_WS('|', u.sub_tipp, u.sub_txtrating, u.sub_rating))) > 0
      THEN CONCAT_WS('|',
           CASE WHEN u.sub_tipp IS NULL THEN NULL ELSE CONCAT('»',UPPER(u.sub_tipp),'«') END,
           u.sub_txtrating,
           REGEXP_REPLACE(REGEXP_REPLACE(u.sub_rating, '^/ ', ''), ' / ', ' ¦ ')
         )
      ELSE NULL
    END
    ) AS part1_content
  FROM useevents u
),
DescriptionPart2 AS (
  -- CTE for the second part of the description, now with explicit grouping using CONCAT_WS.
  SELECT
    u.cnt_useid,
    u.cnt_eventid,
    CONCAT_WS('||',
      -- Group I: Topic and Long Description (can be a standalone block)
      CASE
        WHEN LENGTH(TRIM(CONCAT_WS('|', u.sub_topic, u.sub_longdescription))) > 0
        THEN CONCAT_WS('|',
             CASE WHEN u.sub_topic IS NULL THEN NULL ELSE CONCAT('Thema: ', u.sub_topic) END,
             u.sub_longdescription
           )
        ELSE NULL
      END,
      -- Group II: Moderator, Commentator, Guests
      CASE
        WHEN LENGTH(TRIM(CONCAT_WS('|', u.sub_moderator, u.sub_commentator, u.sub_guest))) > 0
        THEN CONCAT_WS('|',
             CASE WHEN u.sub_moderator IS NULL THEN NULL ELSE CONCAT('Moderation: ', u.sub_moderator) END,
             CASE WHEN u.sub_commentator IS NULL THEN NULL ELSE CONCAT('Kommentar: ', u.sub_commentator) END,
             CASE WHEN u.sub_guest IS NULL THEN NULL ELSE CONCAT('Gäste: ', u.sub_guest) END
           )
        ELSE NULL
      END,
      -- Group III: Genre, Category, Country, Year
      CASE
        WHEN LENGTH(TRIM(CONCAT_WS('|', u.sub_genre, u.sub_category, u.sub_country, u.sub_year))) > 0
        THEN CONCAT_WS('|',
             CASE WHEN u.sub_genre IS NULL THEN NULL ELSE CONCAT('Genre: ', u.sub_genre) END,
             CASE WHEN u.sub_category IS NULL THEN NULL ELSE CONCAT('Kategorie: ', u.sub_category) END,
             CASE WHEN u.sub_country IS NULL THEN NULL ELSE CONCAT('Land: ', u.sub_country) END,
             CASE WHEN u.sub_year IS NULL THEN NULL ELSE CONCAT('Jahr: ', SUBSTRING(u.sub_year, 1, 4)) END
           )
        ELSE NULL
      END,
      -- Group IV: FSK
      CASE
        WHEN u.cnt_parentalrating IS NULL OR u.cnt_parentalrating = 0 THEN NULL
        ELSE CONCAT('FSK: ', u.cnt_parentalrating)
      END,
      -- Group V: Cast (Actors, Producer, Other)
      CASE
        WHEN LENGTH(TRIM(CONCAT_WS('|', u.sub_actor, u.sub_producer, u.sub_other))) > 0
        THEN CONCAT_WS('|',
             CASE WHEN u.sub_actor IS NULL THEN NULL ELSE CONCAT('Darsteller: ', u.sub_actor) END,
             CASE WHEN u.sub_producer IS NULL THEN NULL ELSE CONCAT('Produzent: ', u.sub_producer) END,
             CASE WHEN u.sub_other IS NULL THEN NULL ELSE CONCAT('Sonstige: ', u.sub_other) END
           )
        ELSE NULL
      END,
      -- Group VI: Production Team (Director, Screenplay, etc.)
      CASE
        WHEN LENGTH(TRIM(CONCAT_WS('|', u.sub_director, u.sub_screenplay, u.sub_camera, u.sub_music))) > 0
        THEN CONCAT_WS('|',
             CASE WHEN u.sub_director IS NULL THEN NULL ELSE CONCAT('Regie: ', u.sub_director) END,
             CASE WHEN u.sub_screenplay IS NULL THEN NULL ELSE CONCAT('Drehbuch: ', u.sub_screenplay) END,
             CASE WHEN u.sub_camera IS NULL THEN NULL ELSE CONCAT('Kamera: ', u.sub_camera) END,
             CASE WHEN u.sub_music IS NULL THEN NULL ELSE CONCAT('Musik: ', u.sub_music) END
           )
        ELSE NULL
      END,
      -- Group VII: Episode Information
      CASE
        WHEN LENGTH(TRIM(CONCAT_WS('|', u.epi_episodename, u.epi_shortname, u.epi_partname, u.epi_extracol1, u.epi_extracol2, u.epi_extracol3, u.epi_season, u.epi_part, u.epi_parts, u.epi_number))) > 0
        THEN CONCAT_WS('|',
             CASE WHEN u.epi_episodename IS NULL THEN NULL ELSE CONCAT('Serie: ', u.epi_episodename) END,
             CASE WHEN u.epi_shortname IS NULL THEN NULL ELSE CONCAT('Kurzname: ', u.epi_shortname) END,
             CASE WHEN u.epi_partname IS NULL THEN NULL ELSE CONCAT('Episode: ', u.epi_partname) END,
             u.epi_extracol1,
             u.epi_extracol2,
             u.epi_extracol3,
             CASE WHEN u.epi_season IS NULL THEN NULL ELSE CONCAT('Staffel: ', CAST(u.epi_season AS CHAR)) END,
             CASE WHEN u.epi_part IS NULL THEN NULL ELSE CONCAT('Staffelfolge: ', CAST(u.epi_part AS CHAR)) END,
             CASE WHEN u.epi_parts IS NULL THEN NULL ELSE CONCAT('Staffelfolgen: ', CAST(u.epi_parts AS CHAR)) END,
             CASE WHEN u.epi_number IS NULL THEN NULL ELSE CONCAT('Folge: ', CAST(u.epi_number AS CHAR)) END
           )
        ELSE NULL
      END,
      -- Group VIII: Misc (Audio, Flags, and Source)
      CASE
        WHEN LENGTH(TRIM(CONCAT_WS('|', u.sub_audio, u.sub_flags))) > 0 OR u.cnt_source IS NOT NULL
        THEN CONCAT_WS('|',
             CASE WHEN u.sub_audio IS NULL THEN NULL ELSE CONCAT('Audio: ', u.sub_audio) END,
             CASE WHEN u.sub_flags IS NULL THEN NULL ELSE CONCAT('Flags: ', u.sub_flags) END,
             CASE WHEN u.cnt_source <> u.sub_source THEN CONCAT('Quelle: ', UPPER(REPLACE(u.cnt_source,'vdr','dvb')), '/', UPPER(u.sub_source))
             ELSE CONCAT('Quelle: ', UPPER(REPLACE(u.cnt_source,'vdr','dvb'))) END
           )
        ELSE NULL
      END
    ) AS part2_content
  FROM useevents u
)
SELECT
  u.cnt_useid useid,
  u.cnt_eventid eventid,
  u.cnt_channelid channelid,
  u.cnt_source source,
  u.all_updsp updsp,
  u.cnt_updflg updflg,
  u.cnt_delflg delflg,
  u.cnt_fileref fileref,
  u.cnt_tableid tableid,
  u.cnt_version version,
  u.sub_title title,
  CASE
    WHEN u.sub_shorttext IS NULL THEN
      s.formatted_shorttext_part
    ELSE
      CONCAT(
        CASE WHEN LENGTH(IFNULL(u.epi_season,'')) > 0 OR LENGTH(IFNULL(u.epi_part,'')) > 0 THEN '(' ELSE '' END,
        CASE WHEN LENGTH(IFNULL(u.epi_season,'')) > 0 THEN CONCAT('S',LPAD(CAST(u.epi_season AS CHAR),2,'0')) ELSE '' END,
        CASE WHEN LENGTH(IFNULL(u.epi_part,'')) > 0 THEN CONCAT('E', LPAD(CAST(u.epi_part AS CHAR), 2, '0')) ELSE '' END,
        CASE WHEN LENGTH(IFNULL(u.epi_part,'')) > 0 OR LENGTH(IFNULL(u.epi_season,'')) > 0 THEN ') ' ELSE '' END,
        CASE WHEN LENGTH(IFNULL(u.epi_partname,'')) > 0 THEN u.epi_partname ELSE u.sub_shorttext END
      )
  END AS shorttext,
  CASE
    WHEN u.sub_longdescription IS NULL THEN
      u.cnt_longdescription
    ELSE
      u.sub_longdescription
  END AS longdescription,
  CASE
    WHEN u.cnt_source <> u.sub_source THEN
      CONCAT(UPPER(REPLACE(u.cnt_source,'vdr','dvb')),'/',UPPER(u.sub_source))
    ELSE
      UPPER(REPLACE(u.cnt_source,'vdr','dvb'))
  END AS mergesource,
  u.cnt_starttime starttime,
  u.cnt_duration duration,
  u.cnt_parentalrating parentalrating,
  u.cnt_vps vps,
  u.cnt_contents contents,
  -- Merge the prepared parts from the CTEs and replace pipes with newlines
  REPLACE(
    CONCAT_WS('||',
      CASE WHEN u.sub_shorttext IS NULL THEN NULL ELSE s.formatted_shorttext_part END,
      CASE WHEN p1.part1_content = '' THEN NULL ELSE p1.part1_content END,
      CASE WHEN p2.part2_content = '' THEN NULL ELSE p2.part2_content END
    ),
    '|', '\n'
  ) AS description
FROM
  useevents u
JOIN
  ShortTextFormatter s ON u.cnt_useid = s.cnt_useid AND u.cnt_eventid = s.cnt_eventid
LEFT JOIN
  DescriptionPart1 p1 ON u.cnt_useid = p1.cnt_useid AND u.cnt_eventid = p1.cnt_eventid
LEFT JOIN
  DescriptionPart2 p2 ON u.cnt_useid = p2.cnt_useid AND u.cnt_eventid = p2.cnt_eventid;
