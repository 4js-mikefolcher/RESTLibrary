##############################################################################################
# serverHelper.4gl provides functions to define URI endpoints for GET, POST, PUT, and DELETE
# without relying on the database schema.
##############################################################################################
IMPORT com
IMPORT util
IMPORT FGL sqlHelper
IMPORT FGL UserScopes

PUBLIC DEFINE responseError RECORD ATTRIBUTE(WSError="Response Error", json_name="responseError")
	respCode INTEGER,
	respMessage STRING
END RECORD

PUBLIC DEFINE useScopes BOOLEAN = TRUE

PRIVATE DEFINE httpContext DICTIONARY ATTRIBUTE(WSContext) OF STRING

##############################################################################################
#+
#+ startService Starts the web service process and returns a string when it is stopped
#+
##############################################################################################
PUBLIC FUNCTION startService() RETURNS STRING
    DEFINE serviceStatus    INTEGER
    
    CALL com.WebServiceEngine.Start()
    LET int_flag = FALSE
    WHILE int_flag = FALSE
    
      LET serviceStatus = com.WebServiceEngine.ProcessServices(-1)
      CASE serviceStatus
         WHEN 0
            DISPLAY "Request processed."
         WHEN -1
            DISPLAY "Timeout reached."
         WHEN -2
            RETURN "Disconnected from application server."
         WHEN -3
            DISPLAY "Client Connection lost."
         WHEN -4
            DISPLAY "Server interrupted with Ctrl-C."
         WHEN -9
            DISPLAY "Unsupported operation."
         WHEN -10
            DISPLAY "Internal server error."
         WHEN -23
            DISPLAY "Deserialization error."
         WHEN -35
            DISPLAY "No such REST operation found."
         WHEN -36
            DISPLAY "Missing REST parameter."
         OTHERWISE
            RETURN SFMT("Unexpected server error %1.", serviceStatus)
            LET int_flag = TRUE
     END CASE
     
  END WHILE
  RETURN "Server stopped"

END FUNCTION

##############################################################################################
#+
#+ getAllRecords Gets and returns all the records in a table
#+
##############################################################################################
PUBLIC FUNCTION getAllRecords(tableName STRING ATTRIBUTES(WSParam))
    ATTRIBUTES(WSGet,
               WSPath = "/table/{tableName}",
               WSDescription = 'Fetches all the data from the specified table',
               WSThrows = "404:Not Found")
    RETURNS util.JSONArray ATTRIBUTES(WSMedia = "application/json")

    DEFINE jsonArray  util.JSONArray

	 IF NOT authorizationCheck(tableName, UserScopes.cFetchOperation) THEN
		 RETURN jsonArray
	 END IF

    LET jsonArray = sqlHelper.getTableRecords(tableName, -1, -1)

    IF jsonArray IS NULL THEN
        LET responseError.respCode = "999"
        LET responseError.respMessage = SFMT("Table %1 does not exist", tableName)
        CALL com.WebServiceEngine.SetRestError(500, responseError)
    ELSE 
        IF jsonArray.getLength() == 0 THEN
            LET responseError.respCode = "100"
            LET responseError.respMessage = SFMT("Table %1 does not have any records", tableName)
            CALL com.WebServiceEngine.SetRestError(404, responseError)
        END IF
    END IF

    RETURN jsonArray

END FUNCTION

##############################################################################################
#+
#+ getRecordCount Gets and returns all number of records in a table
#+
##############################################################################################
PUBLIC FUNCTION getRecordCount(tableName STRING ATTRIBUTES(WSParam))
    ATTRIBUTES(WSGet,
               WSPath = "/table/{tableName}/count",
               WSDescription = 'Fetches the record count from the specified table',
               WSThrows = "404:Not Found")
    RETURNS INTEGER

    DEFINE lCount  INTEGER

	 IF NOT authorizationCheck(tableName, UserScopes.cFetchOperation) THEN
		 RETURN lCount
	 END IF

    LET lCount = sqlHelper.getTableRecordCount(tableName)

    IF lCount IS NULL THEN
        CALL com.WebServiceEngine.SetRestError(500, NULL)
    ELSE 
        IF lCount == 0 THEN
            CALL com.WebServiceEngine.SetRestError(404, NULL)
        END IF
    END IF

    RETURN lCount

END FUNCTION

##############################################################################################
#+
#+ getRecordCount Gets and returns all number of records in a table
#+
##############################################################################################
PUBLIC FUNCTION getSchema(tableName STRING ATTRIBUTES(WSParam))
    ATTRIBUTES(WSGet,
               WSPath = "/table/{tableName}/schema",
               WSDescription = 'Fetches the table schema for the specified table',
               WSThrows = "404:Not Found")
    RETURNS util.JSONObject

    DEFINE jsonObj util.JSONObject
	 DEFINE schemaList DICTIONARY OF STRING

	 IF NOT authorizationCheck(tableName, UserScopes.cFetchOperation) THEN
		 RETURN jsonObj
	 END IF

    LET schemaList = sqlHelper.getTableSchema(tableName)

    IF schemaList.getLength() == 0 THEN
		 CALL com.WebServiceEngine.SetRestError(404, NULL)
	 ELSE
		 LET jsonObj = util.JSONObject.fromFGL(schemaList)
    END IF

    RETURN jsonObj

END FUNCTION

##############################################################################################
#+
#+ getRecordsWithLimit Gets and returns all the records in a table up to the specified limit
#+
##############################################################################################
PUBLIC FUNCTION getRecordsWithLimit(tableName STRING ATTRIBUTES(WSParam), 
                                    recLimit INTEGER ATTRIBUTES(WSParam))
    ATTRIBUTES(WSGet,
               WSPath = "/table/{tableName}/limit/{recLimit}",
               WSDescription = 'Fetches the reccords from the specified table up to the limit specified',
               WSThrows = "404:Not Found")
    RETURNS util.JSONArray ATTRIBUTES(WSMedia = "application/json")

    DEFINE jsonArray  util.JSONArray

	 IF NOT authorizationCheck(tableName, UserScopes.cFetchOperation) THEN
		 RETURN jsonArray
	 END IF

    LET jsonArray = sqlHelper.getTableRecords(tableName, recLimit, -1)

    IF jsonArray IS NULL THEN
        CALL com.WebServiceEngine.SetRestError(500, NULL)
    ELSE 
        IF jsonArray.getLength() == 0 THEN
            CALL com.WebServiceEngine.SetRestError(404, NULL)
        END IF
    END IF

    RETURN jsonArray

END FUNCTION

##############################################################################################
#+
#+ getRecordsWithLimitOffset Gets and returns all the records in a table starting at the 
#+ specified offset and until the specified limit
#+
#+ This method allows the client to implement paging within the application
#+
##############################################################################################
PUBLIC FUNCTION getRecordsWithLimitOffset(tableName STRING ATTRIBUTES(WSParam), 
                                          recLimit INTEGER ATTRIBUTES(WSParam),
                                          recOffset INTEGER ATTRIBUTES(WSParam))
    ATTRIBUTES(WSGet,
               WSPath = "/table/{tableName}/limit/{recLimit}/offset/{recOffset}",
               WSDescription = 'Fetches the reccords from the specified table up to the limit specified',
               WSThrows = "404:Not Found")
    RETURNS util.JSONArray ATTRIBUTES(WSMedia = "application/json")

    DEFINE jsonArray  util.JSONArray

	 IF NOT authorizationCheck(tableName, UserScopes.cFetchOperation) THEN
		 RETURN jsonArray
	 END IF

    LET jsonArray = sqlHelper.getTableRecords(tableName, recLimit, recOffset)

    IF jsonArray IS NULL THEN
        CALL com.WebServiceEngine.SetRestError(500, NULL)
    ELSE 
        IF jsonArray.getLength() == 0 THEN
            CALL com.WebServiceEngine.SetRestError(404, NULL)
        END IF
    END IF

    RETURN jsonArray

END FUNCTION

##############################################################################################
#+
#+ getRecordsQuery Gets and returns all the records in a table that match the query criteria. 
#+ colName is the name of the column to query
#+ colValue is the column value (for equality)
#+ contains is the column value (for contains)
#+
##############################################################################################
PUBLIC FUNCTION getRecordsQuery(tableName STRING ATTRIBUTES(WSParam),
                                colName STRING ATTRIBUTES(WSQuery, WSOptional, WSName = "column"),
                                colValue STRING ATTRIBUTES(WSQuery, WSOptional, WSName = "value"),
                                contains STRING ATTRIBUTES(WSQuery, WSOptional, WSName = "contains"))
    ATTRIBUTES(WSGet,
               WSPath = "/table/{tableName}/query",
               WSDescription = 'Fetches all the data from the specified table',
               WSThrows = "404:Not Found")
    RETURNS util.JSONArray ATTRIBUTES(WSMedia = "application/json")

    DEFINE jsonArray  util.JSONArray

	 IF NOT authorizationCheck(tableName, UserScopes.cFetchOperation) THEN
		 RETURN jsonArray
	 END IF

    IF colName IS NULL OR colName.getLength() == 0 THEN
        LET jsonArray = sqlHelper.getTableRecords(tableName, -1, -1)
    ELSE
        IF contains.getLength() > 0 THEN
            LET contains = "%", contains.trim(),"%"
            LET jsonArray = sqlHelper.getTableQuery(tableName, colName.trim(), contains, TRUE)
        ELSE 
            IF colValue.getLength() > 0 THEN
                 LET jsonArray = sqlHelper.getTableQuery(tableName, colName.trim(), colValue.trim(), FALSE)
            END IF
        END IF
    END IF

    IF jsonArray IS NULL THEN
        CALL com.WebServiceEngine.SetRestError(500, NULL)
    ELSE 
        IF jsonArray.getLength() == 0 THEN
            CALL com.WebServiceEngine.SetRestError(404, NULL)
        END IF
    END IF

    RETURN jsonArray

END FUNCTION

##############################################################################################
#+
#+ insertTableRecord Inserts the payload into the specified table
#+
##############################################################################################
PUBLIC FUNCTION insertTableRecord(tableName STRING ATTRIBUTES(WSParam), jsonObj util.JSONObject)
  ATTRIBUTES(WSPost,
             WSPath="/table/{tableName}",
             WSDescription='Create a new record',
             WSThrows="404:Not Found")
  RETURNS STRING

    DEFINE lStatusCode      INTEGER

	 IF NOT authorizationCheck(tableName, UserScopes.cInsertOperation) THEN
		 RETURN NULL
	 END IF

    IF jsonObj IS NULL OR jsonObj.toString().getLength() == 0 THEN
        CALL com.WebServiceEngine.SetRestError(404, NULL)
        RETURN "Error 404"
    END IF

    IF tableName.getLength() == 0 THEN
        CALL com.WebServiceEngine.SetRestError(404, NULL)
        RETURN "Error 404"
    END IF

    LET lStatusCode = sqlHelper.insertFromJSON(tableName, jsonObj)
    IF lStatusCode > 0 THEN
        CALL com.WebServiceEngine.SetRestError(lStatusCode, NULL)
        RETURN SFMT("Error %1", lStatusCode)
    END IF
    
    RETURN "Success 200"

END FUNCTION

##############################################################################################
#+
#+ updateTableRecord Updates the payload into the specified table, using the querystring
#+ arguments as the where criteria in the update
#+
##############################################################################################
PUBLIC FUNCTION updateTableRecord(tableName STRING ATTRIBUTES(WSParam),
                                  colName STRING ATTRIBUTES(WSQuery, WSName = "column"),
                                  colValue STRING ATTRIBUTES(WSQuery, WSName = "value"),
                                  jsonObj util.JSONObject)
  ATTRIBUTES(WSPut,
             WSPath="/table/{tableName}",
             WSDescription='Update a record',
             WSThrows="404:Not Found")
 RETURNS STRING

    DEFINE lStatusCode      INTEGER = 0

	 IF NOT authorizationCheck(tableName, UserScopes.cUpdateOperation) THEN
		 RETURN NULL
	 END IF

    IF jsonObj IS NULL OR jsonObj.toString().getLength() == 0 THEN
        CALL com.WebServiceEngine.SetRestError(404, NULL)
        RETURN "Error 404"
    END IF

    IF tableName.getLength() == 0 OR colName.getLength() == 0 OR colValue.getLength() == 0 THEN
        CALL com.WebServiceEngine.SetRestError(404, NULL)
        RETURN "Error 404"
    END IF

    LET lStatusCode = sqlHelper.updateFromJSON(tableName, colName, colValue, jsonObj)
    IF lStatusCode > 0 THEN
        CALL com.WebServiceEngine.SetRestError(lStatusCode, NULL)
        RETURN SFMT("Error %1", lStatusCode)
    END IF

    RETURN "Success 200"

END FUNCTION

##############################################################################################
#+
#+ deleteTableRecord Deletes the record(s) in the specified table, using the querystring
#+ arguments as the where criteria in the delete
#+
##############################################################################################
PUBLIC FUNCTION deleteTableRecord(tableName STRING ATTRIBUTES(WSParam),
                                  colName STRING ATTRIBUTES(WSQuery, WSName = "column"),
                                  colValue STRING ATTRIBUTES(WSQuery, WSName = "value"))
  ATTRIBUTES(WSDelete,
             WSPath="/table/{tableName}",
             WSDescription='Delete a record',
             WSThrows="404:Not Found")
 RETURNS STRING

    DEFINE lStatusCode      INTEGER = 0

	 IF NOT authorizationCheck(tableName, UserScopes.cDeleteOperation) THEN
		 RETURN NULL
	 END IF

    IF tableName.getLength() == 0 OR colName.getLength() == 0 OR colValue.getLength() == 0 THEN
        CALL com.WebServiceEngine.SetRestError(404, NULL)
        RETURN "Error 404"
    END IF

    LET lStatusCode = sqlHelper.deleteRecordWithColumnValue(tableName, colName, colValue)
    IF lStatusCode > 0 THEN
        CALL com.WebServiceEngine.SetRestError(lStatusCode, NULL)
        RETURN SFMT("Error %1", lStatusCode)
    END IF

 RETURN "Success 200"

END FUNCTION

PRIVATE FUNCTION authorizationCheck(tabname STRING, operation STRING) RETURNS BOOLEAN
	DEFINE userScopes TUserScopes

	IF NOT useScopes THEN
		RETURN TRUE
	END IF

	CALL userScopes.init(httpContext["scopes"])
	IF userScopes.hasTableOperation(tabname, operation) THEN
		RETURN TRUE
	END IF

	LET responseError.respCode = "403"
	LET responseError.respMessage = "User not authorized"
	CALL com.WebServiceEngine.SetRestError(403, responseError)
	RETURN FALSE

END FUNCTION #authorizationCheck
