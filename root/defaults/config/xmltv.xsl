<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output method="xml" indent="yes" encoding="UTF-8"/>

    <!-- Variable for loading the category mapping file -->
    <!-- Ensure that 'xmltv-category.xml' is in the same directory as this XSLT file -->
    <xsl:variable name="category_mapping" select="document('xmltv-category.xml')/mapping/categories/category"/>

    <xsl:template match="/tv">
        <tv>
            <!-- Copy all attributes of the original /tv-element -->
            <xsl:apply-templates select="@*"/>
            <xsl:apply-templates select="channel"/>
            <xsl:apply-templates select="programme"/>
        </tv>
    </xsl:template>

    <xsl:template match="channel">
        <channel>
            <xsl:attribute name="id">
                <xsl:value-of select="@id"/>
            </xsl:attribute>
            <display-name>
                <xsl:value-of select="display-name"/>
            </display-name>
        </channel>
    </xsl:template>

    <xsl:template match="programme">
        <event>
            <!-- Copy all attributes of the programme element (e.g., @start, @stop, @channel, @clumpidx) -->
            <xsl:apply-templates select="@*"/>

            <!-- Numeric event ID as attribute: 14-digit timestamp (YYYYMMDDhhmmss) -->
            <!-- This value is unique per channel in combination with channel ID in the database's primary key. -->
            <xsl:attribute name="eventid">
                <xsl:value-of select="substring(@start, 1, 14)"/>
            </xsl:attribute>

            <!-- Programme title -->
            <title>
                <xsl:value-of select="title"/>
            </title>

            <!-- Sub-title mapped to shorttext -->
            <shorttext>
                <xsl:value-of select="sub-title"/>
            </shorttext>

            <!-- Short description and long description based on the length of the <desc> elements -->
            <xsl:variable name="desc1-cleaned">
                <xsl:if test="desc[1]">
                    <xsl:call-template name="strip-html">
                        <xsl:with-param name="text" select="desc[1]"/>
                    </xsl:call-template>
                </xsl:if>
            </xsl:variable>
            <xsl:variable name="desc2-cleaned">
                <xsl:if test="desc[2]">
                    <xsl:call-template name="strip-html">
                        <xsl:with-param name="text" select="desc[2]"/>
                    </xsl:call-template>
                </xsl:if>
            </xsl:variable>

            <shortdescription>
                <xsl:choose>
                    <xsl:when test="count(desc) &gt; 1">
                        <!-- If there are two or more <desc> elements, take the shorter one for shortdescription -->
                        <xsl:if test="string-length(normalize-space($desc1-cleaned)) &lt;= string-length(normalize-space($desc2-cleaned))">
                            <xsl:value-of select="normalize-space(substring($desc1-cleaned, 1, 300))"/>
                        </xsl:if>
                        <xsl:if test="string-length(normalize-space($desc2-cleaned)) &lt; string-length(normalize-space($desc1-cleaned))">
                            <xsl:value-of select="normalize-space(substring($desc2-cleaned, 1, 300))"/>
                        </xsl:if>
                    </xsl:when>
                    <xsl:otherwise>
                        <!-- If only one or no <desc> element is present, shortdescription remains empty -->
                    </xsl:otherwise>
                </xsl:choose>
            </shortdescription>

            <longdescription>
                <xsl:choose>
                    <xsl:when test="count(desc) &gt; 1">
                        <!-- If there are two or more <desc> elements, take the longer one for longdescription -->
                        <xsl:if test="string-length(normalize-space($desc1-cleaned)) &gt; string-length(normalize-space($desc2-cleaned))">
                            <xsl:value-of select="$desc1-cleaned"/>
                        </xsl:if>
                        <xsl:if test="string-length(normalize-space($desc2-cleaned)) &gt;= string-length(normalize-space($desc1-cleaned))">
                            <xsl:value-of select="$desc2-cleaned"/>
                        </xsl:if>
                    </xsl:when>
                    <xsl:when test="count(desc) = 1">
                        <!-- If only one <desc> element is present, take this for longdescription -->
                        <xsl:value-of select="$desc1-cleaned"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <!-- If no <desc> element is present, longdescription remains empty -->
                    </xsl:otherwise>
                </xsl:choose>
            </longdescription>

            <!-- Credits mapping (director, actor, writer, etc.) -->
            <actor>
                <xsl:for-each select="credits/actor">
                    <xsl:value-of select="."/>
                    <xsl:if test="@role">
                        <xsl:text> (</xsl:text>
                        <xsl:value-of select="@role"/>
                        <xsl:text>)</xsl:text>
                    </xsl:if>
                    <xsl:if test="position() != last()">, </xsl:if>
                </xsl:for-each>
            </actor>
            <director>
                <xsl:for-each select="credits/director">
                    <xsl:value-of select="."/>
                    <xsl:if test="position() != last()">, </xsl:if>
                </xsl:for-each>
            </director>
            <producer>
                <xsl:for-each select="credits/producer">
                    <xsl:value-of select="."/>
                    <xsl:if test="position() != last()">, </xsl:if>
                </xsl:for-each>
            </producer>
            <screenplay>
                <xsl:for-each select="credits/writer">
                    <xsl:value-of select="."/>
                    <xsl:if test="position() != last()">, </xsl:if>
                </xsl:for-each>
            </screenplay>
            <commentator>
                <xsl:for-each select="credits/commentator">
                    <xsl:value-of select="."/>
                    <xsl:if test="position() != last()">, </xsl:if>
                </xsl:for-each>
            </commentator>
            <moderator>
                <xsl:for-each select="credits/presenter">
                    <xsl:value-of select="."/>
                    <xsl:if test="position() != last()">, </xsl:if>
                </xsl:for-each>
            </moderator>
            <guest>
                <xsl:for-each select="credits/guest">
                    <xsl:value-of select="."/>
                    <xsl:if test="position() != last()">, </xsl:if>
                </xsl:for-each>
            </guest>
            <camera>
                <xsl:for-each select="credits/camera">
                    <xsl:value-of select="."/>
                    <xsl:if test="position() != last()">, </xsl:if>
                </xsl:for-each>
            </camera>
            <music>
                <xsl:for-each select="credits/composer">
                    <xsl:value-of select="."/>
                    <xsl:if test="position() != last()">, </xsl:if>
                </xsl:for-each>
            </music>

            <!-- Date (year) -->
            <year>
                <xsl:value-of select="date"/>
            </year>

            <!-- Category mapping is applied via the named template 'mapping' -->
            <xsl:call-template name="mapping">
                <xsl:with-param name="str" select="category" />
            </xsl:call-template>

            <!-- Original category is additionally mapped as Genre -->
            <genre>
                <xsl:value-of select="category"/>
            </genre>
            
            <!-- Country of origin -->
            <country>
                <xsl:value-of select="country"/>
            </country>

            <!-- Episode number -->
            <extepnum>
                <xsl:value-of select="episode-num[@system='xmltv_ns']"/> <!-- Assuming xmltv_ns for structured episode number -->
            </extepnum>

            <!-- Language is ignored to avoid "Missing definition of field 'events.language'" error -->
            <!-- <language>
                <xsl:value-of select="language"/>
            </language> -->

            <!-- Rating: Mapped from 'Rating by Genre' review, with fallback to other text reviews -->
            <rating>
                <xsl:variable name="rating_conclusion" select="review[@type='text' and @source='Rating Conclusion']"/>
                <xsl:variable name="rating_by_genre" select="review[@type='text' and @source='Rating by Genre']"/>
                <xsl:choose>
                    <xsl:when test="$rating_by_genre != ''">
                        <xsl:value-of select="$rating_by_genre"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <!-- Fallback to the first text review that is not the 'Rating Conclusion' one -->
                        <xsl:value-of select="review[@type='text'][not(@source='Rating Conclusion')][1]"/>
                    </xsl:otherwise>
                </xsl:choose>
            </rating>

            <!-- Text rating: Mapped from 'Rating Conclusion' review. It will be empty if not found. -->
            <txtrating>
                <xsl:variable name="rating_conclusion" select="review[@type='text' and @source='Rating Conclusion']"/>
                <xsl:if test="$rating_conclusion != ''">
                    <xsl:value-of select="$rating_conclusion"/>
                </xsl:if>
            </txtrating>

            <!-- Numeric rating: Complex calculation based on TVSpielfilm, IMDB, and Tipp presence -->
            <numrating>
                <xsl:variable name="tvspielfilm_raw_val" select="star-rating[@system='TVSpielfilm']/value"/>
                <xsl:variable name="imdb_raw_val" select="star-rating[@system='IMDB']/value"/>
                
                <xsl:variable name="tvspielfilm_num">
                    <xsl:if test="$tvspielfilm_raw_val != '' and contains($tvspielfilm_raw_val, ' / ')">
                        <xsl:value-of select="number(substring-before($tvspielfilm_raw_val, ' / '))"/>
                    </xsl:if>
                </xsl:variable>

                <xsl:variable name="imdb_score">
                    <xsl:if test="$imdb_raw_val != '' and contains($imdb_raw_val, ' / ')">
                        <xsl:value-of select="number(substring-before(translate($imdb_raw_val, ',', '.'), ' / '))"/>
                    </xsl:if>
                </xsl:variable>

                <!-- TVSpielfilm base rating (no inversion needed, as per user's latest clarification) -->
                <xsl:variable name="tvspielfilm_base">
                    <xsl:if test="string-length($tvspielfilm_num) &gt; 0">
                        <xsl:value-of select="$tvspielfilm_num"/>
                    </xsl:if>
                </xsl:variable>

                <xsl:variable name="scaled_imdb_val">
                    <xsl:if test="string-length($imdb_score) &gt; 0 and $imdb_score &gt;= 1 and $imdb_score &lt;= 10">
                        <xsl:value-of select="floor(1 + ($imdb_score - 1) * 4 div 9 + 0.5)"/>
                    </xsl:if>
                </xsl:variable>

                <xsl:variable name="bonus_from_imdb">
                    <xsl:choose>
                        <xsl:when test="string-length($imdb_score) &gt; 0 and $imdb_score &gt;= 8">1</xsl:when>
                        <xsl:otherwise>0</xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                
                <!-- Corrected 'Tipp' source for bonus calculation -->
                <xsl:variable name="bonus_from_tipp">
                    <xsl:choose>
                        <xsl:when test="review[@type='text' and @source='Tipp']">1</xsl:when>
                        <xsl:otherwise>0</xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>

                <xsl:choose>
                    <xsl:when test="string-length($tvspielfilm_num) &gt; 0">
                        <xsl:variable name="calculated_rating" select="number($tvspielfilm_base)"/>
                        <xsl:variable name="total_bonus" select="number($bonus_from_imdb) + number($bonus_from_tipp)"/>
                        <xsl:variable name="pre_final_rating" select="$calculated_rating + $total_bonus"/>

                        <xsl:choose>
                            <xsl:when test="number($pre_final_rating) &gt; 5">5</xsl:when>
                            <xsl:otherwise><xsl:value-of select="$pre_final_rating"/></xsl:otherwise>
                        </xsl:choose>
                    </xsl:when>
                    <xsl:when test="string-length($imdb_score) &gt; 0">
                        <xsl:value-of select="$scaled_imdb_val"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <!-- If neither TVSpielfilm nor IMDB is present, check for any other star-rating -->
                        <xsl:variable name="other_star_rating_raw" select="star-rating[not(@system='TVSpielfilm') and not(@system='IMDB')][1]/value"/>
                        <xsl:if test="$other_star_rating_raw != '' and contains($other_star_rating_raw, ' / ')">
                            <xsl:value-of select="number(substring-before($other_star_rating_raw, ' / '))"/>
                        </xsl:if>
                    </xsl:otherwise>
                </xsl:choose>
            </numrating>

            <!-- Parental rating: Extracts value from 'FSK' system if available and not zero -->
            <parentalrating>
                <xsl:variable name="fsk_value" select="rating[@system='FSK']/value"/>
                <xsl:if test="number($fsk_value) != 0">
                    <xsl:value-of select="number($fsk_value)"/>
                </xsl:if>
            </parentalrating>

            <!-- Tipp mapping: Mapped from 'Rating Average' review (corrected source to 'Tipp') -->
            <xsl:if test="review[@type='text' and @source='Tipp']">
                <tipp>
                    <xsl:value-of select="review[@type='text' and @source='Tipp']"/>
                </tipp>
            </xsl:if>

            <!-- Placeholder for start time and duration. These are typically calculated by the epgd-plugin itself
                 from the @start and @stop attributes of the programme element and converted to its internal format.
                 Therefore, dummy values are provided here. -->
            <starttime>0</starttime>
            <duration>0</duration>
        </event>
    </xsl:template>

    <!--
    ####################################################################################################
    # IGNORED ELEMENTS
    # Templates below are used to explicitly ignore elements from the XMLTV input that are not mapped
    # to epgd fields to prevent "Missing definition of field" errors in the epgd log.
    ####################################################################################################
    -->
    <xsl:template match="audio"/>
    <xsl:template match="icon"/>
    <xsl:template match="image"/>
    <xsl:template match="keyword"/>
    <xsl:template match="language"/>
    <xsl:template match="last-chance"/>
    <xsl:template match="new"/>
    <xsl:template match="orig-language"/>
    <xsl:template match="premiere"/>
    <xsl:template match="previously-shown"/>
    <xsl:template match="review"/>
    <xsl:template match="star-rating"/>
    <xsl:template match="subtitles"/>
    <xsl:template match="url"/>
    <xsl:template match="video"/>

    <!--
    ####################################################################################################
    # HELPER TEMPLATES
    # These are named templates used for common tasks like stripping HTML or mapping categories.
    ####################################################################################################
    -->

    <!-- Helper template to strip HTML tags from a string (XSLT 1.0 compatible) -->
    <xsl:template name="strip-html">
        <xsl:param name="text"/>
        <xsl:choose>
            <xsl:when test="contains($text, '&lt;') and contains($text, '&gt;')">
                <!-- Retain text before the first '<' -->
                <xsl:value-of select="substring-before($text, '&lt;')"/>
                <!-- Recursive call with the text after the first '>' -->
                <xsl:call-template name="strip-html">
                    <xsl:with-param name="text" select="substring-after($text, '&gt;')"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <!-- If no further tags are found, output the rest of the text -->
                <xsl:value-of select="$text"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- Standard template for copying attributes -->
    <xsl:template match="@*">
        <xsl:copy/>
    </xsl:template>

    <!-- Named template for category mapping -->
    <xsl:template name="mapping">
        <xsl:param name="str" select="." />
        <xsl:variable name="value" select="translate($str,'ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖU', 'abcdefghijklmnopqrstuvwxyzäöü')" />
        <xsl:variable name="map" select="$category_mapping[contains[contains($value, .)]]/@name" />
        <xsl:choose>
            <xsl:when test="string-length($map)">
                <category><xsl:value-of select="$map"/></category>
            </xsl:when>
            <xsl:otherwise>
                <category><xsl:text>Sonstige</xsl:text></category>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

</xsl:stylesheet>
