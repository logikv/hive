-- Upgrade MetaStore schema from 3.2.0 to 4.0.0
-- HIVE-19416
ALTER TABLE "APP"."TBLS" ADD WRITE_ID bigint DEFAULT 0;
ALTER TABLE "APP"."PARTITIONS" ADD WRITE_ID bigint DEFAULT 0;

-- HIVE-20793
ALTER TABLE "APP"."WM_RESOURCEPLAN" ADD NS VARCHAR(128);
UPDATE "APP"."WM_RESOURCEPLAN" SET NS = 'default' WHERE NS IS NULL;
DROP INDEX "APP"."UNIQUE_WM_RESOURCEPLAN";
CREATE UNIQUE INDEX "APP"."UNIQUE_WM_RESOURCEPLAN" ON "APP"."WM_RESOURCEPLAN" ("NS", "NAME");

-- HIVE-21063
CREATE UNIQUE INDEX "APP"."NOTIFICATION_LOG_EVENT_ID" ON "APP"."NOTIFICATION_LOG" ("EVENT_ID");

-- HIVE-22046 (DEFAULT HIVE)
ALTER TABLE "APP"."TAB_COL_STATS" ADD ENGINE VARCHAR(128);
UPDATE "APP"."TAB_COL_STATS" SET ENGINE = 'hive' WHERE ENGINE IS NULL;
ALTER TABLE "APP"."PART_COL_STATS" ADD ENGINE VARCHAR(128);
UPDATE "APP"."PART_COL_STATS" SET ENGINE = 'hive' WHERE ENGINE IS NULL;

CREATE TABLE "APP"."SCHEDULED_QUERIES" (
  "SCHEDULED_QUERY_ID" bigint primary key not null,
  "SCHEDULE_NAME" varchar(256) not null,
  "ENABLED" CHAR(1) NOT NULL DEFAULT 'N',
  "CLUSTER_NAMESPACE" varchar(256) not null,
  "USER" varchar(128) not null,
  "SCHEDULE" varchar(256) not null,
  "QUERY" varchar(4000) not null,
  "NEXT_EXECUTION" integer
);

CREATE INDEX NEXTEXECUTIONINDEX ON APP.SCHEDULED_QUERIES (ENABLED,CLUSTER_NAMESPACE,NEXT_EXECUTION);
CREATE UNIQUE INDEX UNIQUE_SCHEDULED_QUERIES_NAME ON APP.SCHEDULED_QUERIES (SCHEDULE_NAME,CLUSTER_NAMESPACE);

CREATE TABLE APP.SCHEDULED_EXECUTIONS (
        SCHEDULED_EXECUTION_ID bigint primary key not null,
        EXECUTOR_QUERY_ID VARCHAR(256),
        SCHEDULED_QUERY_ID bigint not null,
        START_TIME integer not null,
        END_TIME INTEGER,
        LAST_UPDATE_TIME INTEGER,
        ERROR_MESSAGE VARCHAR(2000),
        STATE VARCHAR(256),
        CONSTRAINT SCHEDULED_EXECUTIONS_SCHQ_FK FOREIGN KEY (SCHEDULED_QUERY_ID) REFERENCES APP.SCHEDULED_QUERIES(SCHEDULED_QUERY_ID) ON DELETE CASCADE
);

CREATE INDEX LASTUPDATETIMEINDEX ON APP.SCHEDULED_EXECUTIONS (LAST_UPDATE_TIME);
CREATE INDEX SCHEDULED_EXECUTIONS_SCHQID ON APP.SCHEDULED_EXECUTIONS (SCHEDULED_QUERY_ID);
CREATE UNIQUE INDEX SCHEDULED_EXECUTIONS_UNIQUE_ID ON APP.SCHEDULED_EXECUTIONS (SCHEDULED_EXECUTION_ID);

-- HIVE-22729
ALTER TABLE COMPACTION_QUEUE ADD CQ_ERROR_MESSAGE clob;
ALTER TABLE COMPLETED_COMPACTIONS ADD CC_ERROR_MESSAGE clob;

-- HIVE-23683
ALTER TABLE COMPACTION_QUEUE ADD CQ_ENQUEUE_TIME bigint;
ALTER TABLE COMPLETED_COMPACTIONS ADD CC_ENQUEUE_TIME bigint;

-- HIVE-22728
ALTER TABLE "APP"."KEY_CONSTRAINTS" DROP CONSTRAINT "CONSTRAINTS_PK";
ALTER TABLE "APP"."KEY_CONSTRAINTS" ADD CONSTRAINT "CONSTRAINTS_PK" PRIMARY KEY ("PARENT_TBL_ID", "CONSTRAINT_NAME", "POSITION");

-- HIVE-21487
CREATE INDEX COMPLETED_COMPACTIONS_RES ON COMPLETED_COMPACTIONS (CC_DATABASE,CC_TABLE,CC_PARTITION);
-- HIVE-22872
ALTER TABLE "SCHEDULED_QUERIES" ADD "ACTIVE_EXECUTION_ID" bigint;

-- HIVE-22995
ALTER TABLE "APP"."DBS" ADD COLUMN "DB_MANAGED_LOCATION_URI" VARCHAR(4000);

-- HIVE-23107
ALTER TABLE COMPACTION_QUEUE ADD CQ_NEXT_TXN_ID bigint;
DROP TABLE MIN_HISTORY_LEVEL;

-- HIVE-23048
INSERT INTO TXNS (TXN_ID, TXN_STATE, TXN_STARTED, TXN_LAST_HEARTBEAT, TXN_USER, TXN_HOST)
  SELECT COALESCE(MAX(CTC_TXNID),0), 'c', 0, 0, '_', '_' FROM COMPLETED_TXN_COMPONENTS;
INSERT INTO TXNS (TXN_ID, TXN_STATE, TXN_STARTED, TXN_LAST_HEARTBEAT, TXN_USER, TXN_HOST)
  VALUES (1000000000, 'c', 0, 0, '_', '_');
ALTER TABLE TXNS ADD COLUMN TXN_ID_TMP bigint;
UPDATE TXNS SET TXN_ID_TMP=TXN_ID;
ALTER TABLE TXNS DROP COLUMN TXN_ID;
ALTER TABLE TXNS ADD COLUMN TXN_ID BIGINT PRIMARY KEY GENERATED BY DEFAULT AS IDENTITY (START WITH 1000000001, INCREMENT BY 1);
UPDATE TXNS SET TXN_ID=TXN_ID_TMP;
ALTER TABLE TXNS DROP COLUMN TXN_ID_TMP;

RENAME TABLE NEXT_TXN_ID TO TXN_LOCK_TBL;
RENAME COLUMN TXN_LOCK_TBL.NTXN_NEXT TO TXN_LOCK;

--HIVE-23516
CREATE TABLE "APP"."REPLICATION_METRICS" (
  "RM_SCHEDULED_EXECUTION_ID" bigint NOT NULL,
  "RM_POLICY" varchar(256) NOT NULL,
  "RM_DUMP_EXECUTION_ID" bigint NOT NULL,
  "RM_METADATA" varchar(4000),
  "RM_PROGRESS" varchar(4000),
  "RM_START_TIME" integer not null,
  PRIMARY KEY("RM_SCHEDULED_EXECUTION_ID")
);

CREATE INDEX "POLICY_IDX" ON "APP"."REPLICATION_METRICS" ("RM_POLICY");
CREATE INDEX "DUMP_IDX" ON "APP"."REPLICATION_METRICS" ("RM_DUMP_EXECUTION_ID");

-- Create stored procedure tables
CREATE TABLE "APP"."STORED_PROCS" (
  "SP_ID" BIGINT NOT NULL,
  "CREATE_TIME" INTEGER NOT NULL,
  "DB_ID" BIGINT NOT NULL,
  "NAME" VARCHAR(256) NOT NULL,
  "OWNER_NAME" VARCHAR(128) NOT NULL,
  "SOURCE" clob NOT NULL,
  PRIMARY KEY ("SP_ID")
);

CREATE UNIQUE INDEX "UNIQUESTOREDPROC" ON "STORED_PROCS" ("NAME", "DB_ID");
ALTER TABLE "STORED_PROCS" ADD CONSTRAINT "STOREDPROC_FK1" FOREIGN KEY ("DB_ID") REFERENCES "DBS" ("DB_ID");

-- This needs to be the last thing done.  Insert any changes above this line.
UPDATE "APP".VERSION SET SCHEMA_VERSION='4.0.0', VERSION_COMMENT='Hive release version 4.0.0' where VER_ID=1;
