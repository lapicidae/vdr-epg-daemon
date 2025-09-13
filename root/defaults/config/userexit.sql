CREATE PROCEDURE userexit ()
BEGIN
  /*
  * This procedure is a workaround to fix event durations.
  * It sets the 'duration' field to 1 for events where it is 0.
  *
  * This prevents a "Division by 0" error that can occur in subsequent
  * processes, such as 'mergeepg'. The issue affects events from
  * 'tvm', 'tvsp', and 'xmltv' sources.
  */
  UPDATE
    events
  SET
    duration = 1
  WHERE
    source IN('tvm','tvsp','xmltv')
    AND duration = 0;
END
