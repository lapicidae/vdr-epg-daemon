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
    TRIM(LEADING '|' FROM CONCAT(
      CASE WHEN u.sub_shortdescription IS NULL THEN '' ELSE u.sub_shortdescription END,
      CASE WHEN u.sub_shortreview IS NULL THEN '' ELSE CONCAT('|',u.sub_shortreview) END,
      CASE WHEN u.sub_tipp IS NULL AND u.sub_txtrating IS NULL AND u.sub_rating IS NULL THEN '' ELSE '|' END,
      CASE WHEN u.sub_tipp IS NULL THEN '' ELSE CONCAT('|»',UPPER(u.sub_tipp),'« ') END,
      CASE WHEN u.sub_txtrating IS NULL THEN '' ELSE CASE WHEN u.sub_tipp IS NULL THEN CONCAT('|',u.sub_txtrating) ELSE u.sub_txtrating END END,
      CASE WHEN u.sub_rating IS NULL THEN ''
           ELSE CONCAT('|', REGEXP_REPLACE(REGEXP_REPLACE(u.sub_rating, '^/ ', ''), ' / ', ' ¦ '))
      END
    )) AS part1_content
  FROM useevents u
),
DescriptionPart2 AS (
  -- CTE for the second part of the description (topic, moderators, genre, country, year, FSK, actors etc.)
  SELECT
    u.cnt_useid,
    u.cnt_eventid,
    TRIM(LEADING '|' FROM CONCAT(
      CASE WHEN u.sub_topic IS NULL THEN '' ELSE CONCAT('Thema: ',u.sub_topic) END,
      CASE WHEN u.sub_longdescription IS NULL THEN '' ELSE CONCAT('|',u.sub_longdescription) END,
      CASE WHEN u.sub_moderator IS NULL THEN '' ELSE CONCAT('|','Moderator: ',u.sub_moderator) END,
      CASE WHEN u.sub_commentator IS NULL THEN '' ELSE CONCAT('|','Kommentar: ',u.sub_commentator) END,
      CASE WHEN u.sub_guest IS NULL THEN '' ELSE CONCAT('|','Gäste: ',u.sub_guest) END,
      CASE WHEN u.sub_genre IS NULL THEN '' ELSE CONCAT('||','Genre: ',u.sub_genre) END,
      CASE WHEN u.sub_category IS NULL THEN '' ELSE CONCAT('|','Kategorie: ',u.sub_category) END,
      CASE WHEN u.sub_country IS NULL THEN '' ELSE CONCAT('|','Land: ',u.sub_country) END,
      CASE WHEN u.sub_year IS NULL THEN '' ELSE CONCAT('|','Jahr: ',SUBSTRING(u.sub_year,1,4)) END,
      CASE WHEN u.cnt_parentalrating IS NULL OR u.cnt_parentalrating = 0 THEN '' ELSE CONCAT('||','FSK: ',u.cnt_parentalrating) END,
      CASE WHEN u.sub_actor IS NULL AND u.sub_producer IS NULL AND u.sub_other IS NULL THEN '' ELSE '|' END,
      CASE WHEN u.sub_actor IS NULL THEN '' ELSE CONCAT('|','Darsteller: ',u.sub_actor) END,
      CASE WHEN u.sub_producer IS NULL THEN '' ELSE CONCAT('|','Produzent: ',u.sub_producer) END,
      CASE WHEN u.sub_other IS NULL THEN '' ELSE CONCAT('|','Sonstige: ',u.sub_other) END,
      CASE WHEN u.sub_director IS NULL AND u.sub_screenplay IS NULL AND u.sub_camera IS NULL AND u.sub_music IS NULL AND u.sub_audio IS NULL AND u.sub_flags IS NULL THEN '' ELSE '|' END,
      CASE WHEN u.sub_director IS NULL THEN '' ELSE CONCAT('|','Regie: ',u.sub_director) END,
      CASE WHEN u.sub_screenplay IS NULL THEN '' ELSE CONCAT('|','Drehbuch: ',u.sub_screenplay) END,
      CASE WHEN u.sub_camera IS NULL THEN '' ELSE CONCAT('|','Kamera: ',u.sub_camera) END,
      CASE WHEN u.sub_music IS NULL THEN '' ELSE CONCAT('|','Musik: ',u.sub_music) END,
      CASE WHEN u.sub_audio IS NULL THEN '' ELSE CONCAT('|','Audio: ',u.sub_audio) END,
      CASE WHEN u.sub_flags IS NULL THEN '' ELSE CONCAT('|','Flags: ',u.sub_flags) END,
      CASE WHEN u.epi_episodename IS NULL THEN '' ELSE CONCAT('||','Serie: ',u.epi_episodename) END,
      CASE WHEN u.epi_shortname IS NULL THEN '' ELSE CONCAT('|','Kurzname: ',u.epi_shortname) END,
      CASE WHEN u.epi_partname IS NULL THEN '' ELSE CONCAT('|','Episode: ',u.epi_partname) END,
      CASE WHEN u.epi_extracol1 IS NULL THEN '' ELSE CONCAT('|',u.epi_extracol1) END,
      CASE WHEN u.epi_extracol2 IS NULL THEN '' ELSE CONCAT('|',u.epi_extracol2) END,
      CASE WHEN u.epi_extracol3 IS NULL THEN '' ELSE CONCAT('|',u.epi_extracol3) END,
      CASE WHEN u.epi_season IS NULL THEN '' ELSE CONCAT('|','Staffel: ',CAST(u.epi_season AS CHAR)) END,
      CASE WHEN u.epi_part IS NULL THEN '' ELSE CONCAT('|','Staffelfolge: ',CAST(u.epi_part AS CHAR)) END,
      CASE WHEN u.epi_parts IS NULL THEN '' ELSE CONCAT('|','Staffelfolgen: ',CAST(u.epi_parts AS CHAR)) END,
      CASE WHEN u.epi_number IS NULL THEN '' ELSE CONCAT('|','Folge: ',CAST(u.epi_number AS CHAR)) END,
      CASE WHEN u.cnt_source <> u.sub_source THEN CONCAT('||','Quelle: ',UPPER(REPLACE(u.cnt_source,'vdr','dvb')),'/',UPPER(u.sub_source)) ELSE CONCAT('||','Quelle: ',UPPER(REPLACE(u.cnt_source,'vdr','dvb'))) END
    )) AS part2_content
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
  -- Merge the prepared parts from the CTEs and remove leading pipes before replacing with newlines
  REPLACE(
    TRIM(LEADING '|' FROM CONCAT(
      CASE WHEN u.sub_shorttext IS NULL THEN '' ELSE s.formatted_shorttext_part END,
      CASE WHEN p1.part1_content = '' THEN '' ELSE CONCAT('||', p1.part1_content) END,
      CASE WHEN p2.part2_content = '' THEN '' ELSE CONCAT('||', p2.part2_content) END
    )),
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
