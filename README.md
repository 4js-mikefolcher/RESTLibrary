# RESTLibrary
RESTLibrary is a generic library to write RESTful web services in Genero

Implements Generic GET, POST, PUT, and DELETE requests for all the tables
in the database.

The Library consists of files to allow for generic select, insert, 
update, and delete statements.

------------------------------------------------
Example Code Snippet from Genero-REST
------------------------------------------------

IMPORT com
IMPORT FGL serviceHelper

MAIN
  DEFINE lMessage STRING
  CONNECT TO "custdemo"
  CALL com.WebServiceEngine.RegisterRestService("serviceHelper","custdemo")

  CALL STARTLOG("custdemoService.log")

  DISPLAY "Server started"
  LET lMessage = serviceHelper.startService()
  DISPLAY lMessage

END MAIN

------------------------------------------------
serviceHelper.4gl: Defines the web service URI's
------------------------------------------------
Get All Records: /table/{tableName}

Get Record Count: /table/{tableName}/count

Get First x Records: /table/{tableName}/limit/{recLimit}

Get First x Records with y Offset: /table/{tableName}/limit/{recLimit}/offset/{recOffset}

Get Records with Query Equal: /table/{tableName}/query?column={colName}&value={colValue}

Get Records with Query Contains: /table/{tableName}/query?column={colName}&contains={colValue}

Post Record: /table/{tableName}
        Body: { "colName": "colValue", .... }

Put Record: /table/{tableName}?column={colName}&value={colValue}
        Body: { "colName": "colValue", .... }

Delete Record: /table/{tableName}?column={colName}&value={colValue}

---------------------------------------------
sqlHelper.4gl: Defines the database interface
---------------------------------------------
PUBLIC FUNCTION getTableRecords(tableName STRING, recLimit INTEGER, recOffset INTEGER) 
 RETURNS util.JSONArray
 
PUBLIC FUNCTION getTableQuery(tableName STRING, colName STRING, colValue STRING, useLike BOOLEAN)
 RETURNS util.JSONArray
 
PUBLIC FUNCTION getTableRecordCount(tableName STRING) RETURNS INTEGER

PUBLIC FUNCTION insertFromJSON(tableName STRING, jsonObj util.JSONObject) RETURNS INTEGER

PUBLIC FUNCTION updateFromJSON(tableName STRING,
                               colName STRING,
                               colValue STRING,
                               jsonObj util.JSONObject) 
 RETURNS INTEGER
 
PUBLIC FUNCTION deleteRecordWithColumnValue(tableName STRING, colName STRING, colValue STRING)
 RETURNS INTEGER
 

