-- An audit history is important on most tables. Provide an audit trigger that logs to
-- a dedicated audit table for the major relations.
--
-- This trigger is based on:
--
--    https://github.com/2ndQuadrant/audit-trigger
--
-- but has been modified to use JSONB insead of HSTORE
--

--
-- Implments "JSONB - keys[]", returns a JSONB document with the keys removed
--
--    http://schinckel.net/2014/09/29/adding-json%28b%29-operators-to-postgresql/

-- param 0: JSONB, source JSONB document to remove keys from
-- param 1: text[], keys to remove from the JSONB document
--
CREATE OR REPLACE FUNCTION "jsonb_minus"(
  "json" jsonb,
  "keys" TEXT[]
)
  RETURNS jsonb
  LANGUAGE sql
  IMMUTABLE
  STRICT
AS $function$
  SELECT
    -- Only executes opration if the JSON document has the keys
    CASE WHEN "json" ?| "keys"
      THEN COALESCE(
          (SELECT ('{' || string_agg(to_json("key")::text || ':' || "value", ',') || '}')
           FROM jsonb_each("json")
           WHERE "key" <> ALL ("keys")),
          '{}'
        )::jsonb
      ELSE "json"
    END
$function$;


CREATE OPERATOR - (
  LEFTARG = jsonb,
  RIGHTARG = text[],
  PROCEDURE = jsonb_minus
);


--
-- Implments "JSONB - JSONB", returns a recursive diff of the JSON documents
--
-- http://coussej.github.io/2016/05/24/A-Minus-Operator-For-PostgreSQLs-JSONB/
--
-- param 0: JSONB, primary JSONB source document to compare
-- param 1: JSONB, secondary JSONB source document to compare
--
CREATE OR REPLACE FUNCTION jsonb_minus ( arg1 jsonb, arg2 jsonb )
RETURNS jsonb
AS $$

  SELECT
    COALESCE(
      json_object_agg(
        key,
        CASE
          -- if the value is an object and the value of the second argument is
          -- not null, we do a recursion
          WHEN jsonb_typeof(value) = 'object' AND arg2 -> key IS NOT NULL
          THEN jsonb_minus(value, arg2 -> key)
          -- for all the other types, we just return the value
          ELSE value
        END
      ),
    '{}'
    )::jsonb
  FROM
    jsonb_each(arg1)
  WHERE
    arg1 -> key <> arg2 -> key
    OR arg2 -> key IS NULL

$$ LANGUAGE SQL;


CREATE OPERATOR - (
  LEFTARG = jsonb,
  RIGHTARG = jsonb,
  PROCEDURE = jsonb_minus
);


CREATE SCHEMA audit;
REVOKE ALL ON SCHEMA audit FROM public;
COMMENT ON SCHEMA audit IS 'Out-of-table audit/history logging tables and trigger functions';

--
-- Audited data. Lots of information is available, it's just a matter of how
-- much you really want to record. See:
--
--   http://www.postgresql.org/docs/9.1/static/functions-info.html
--
-- Remember, every column you add takes up more audit table space and slows
-- audit inserts.
--
-- Every index you add has a big impact too, so avoid adding indexes to the
-- audit table unless you REALLY need them. The hstore GIST indexes are
-- particularly expensive.
--
-- It is sometimes worth copying the audit table, or a coarse subset of it
-- that you're interested in, into a temporary table where you CREATE any
-- useful indexes and do your analysis.
--
CREATE TABLE audit.log (
    id bigserial NOT NULL PRIMARY KEY,
    schema_name text NOT NULL,
    table_name text NOT NULL,
    relid oid NOT NULL,
    "session_user" text NOT NULL,
    action_tstamp_tx TIMESTAMP WITH TIME ZONE NOT NULL,
    action_tstamp_stm TIMESTAMP WITH TIME ZONE NOT NULL,
    action_tstamp_clk TIMESTAMP WITH TIME ZONE NOT NULL,
    transaction_id bigint,
    application_name text,
    application_user text,
    client_addr inet,
    client_port integer,
    client_query text,
    action TEXT NOT NULL CHECK (action IN ('I','D','U', 'T')),
    original JSONB,
    diff JSONB,
    statement_only boolean not null
);

REVOKE ALL ON audit.log FROM public;

COMMENT ON TABLE audit.log IS 'History of auditable actions on audited tables, from audit.if_modified_func()';
COMMENT ON COLUMN audit.log.id IS 'Unique identifier for each auditable event';
COMMENT ON COLUMN audit.log.schema_name IS 'Database schema audited table for this event is in';
COMMENT ON COLUMN audit.log.table_name IS 'Non-schema-qualified table name of table event occured in';
COMMENT ON COLUMN audit.log.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';
COMMENT ON COLUMN audit.log.session_user IS 'Login / session user whose statement caused the audited event';
COMMENT ON COLUMN audit.log.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';
COMMENT ON COLUMN audit.log.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';
COMMENT ON COLUMN audit.log.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';
COMMENT ON COLUMN audit.log.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';
COMMENT ON COLUMN audit.log.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';
COMMENT ON COLUMN audit.log.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';
COMMENT ON COLUMN audit.log.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';
COMMENT ON COLUMN audit.log.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';
COMMENT ON COLUMN audit.log.action IS 'Action type; I = insert, D = delete, U = update, T = truncate';
COMMENT ON COLUMN audit.log.original IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';
COMMENT ON COLUMN audit.log.diff IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';
COMMENT ON COLUMN audit.log.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';

CREATE INDEX log_relid_idx ON audit.log(relid);
CREATE INDEX log_action_tstamp_tx_stm_idx ON audit.log(action_tstamp_stm);
CREATE INDEX log_action_idx ON audit.log(action);

CREATE OR REPLACE FUNCTION audit.if_modified_func() RETURNS TRIGGER AS $body$
DECLARE
    audit_row audit.log;
    excluded_cols text[] = ARRAY[]::text[];
BEGIN
    IF TG_WHEN <> 'AFTER' THEN
        RAISE EXCEPTION 'audit.if_modified_func() may only run as an AFTER trigger';
    END IF;

    audit_row = ROW(
        nextval('audit.log_id_seq'),                  -- log ID
        TG_TABLE_SCHEMA::text,                        -- schema_name
        TG_TABLE_NAME::text,                          -- table_name
        TG_RELID,                                     -- relation OID for much quicker searches
        session_user::text,                           -- session_user
        current_timestamp,                            -- action_tstamp_tx
        statement_timestamp(),                        -- action_tstamp_stm
        clock_timestamp(),                            -- action_tstamp_clk
        txid_current(),                               -- transaction ID
        current_setting('application.name'),          -- client application
        current_setting('application.user'),          -- client user
        inet_client_addr(),                           -- client_addr
        inet_client_port(),                           -- client_port
        current_query(),                              -- top-level query or queries (if multistatement) from client
        substring(TG_OP,1,1),                         -- action
        NULL,                                         -- original
        NULL,                                         -- diff
        'f'                                           -- statement_only
        );

    IF NOT TG_ARGV[0]::boolean IS DISTINCT FROM 'f'::boolean THEN
        audit_row.client_query = NULL;
    END IF;

    IF TG_ARGV[1] IS NOT NULL THEN
        excluded_cols = TG_ARGV[1]::text[];
    END IF;

    IF (TG_OP = 'UPDATE' AND TG_LEVEL = 'ROW') THEN
        audit_row.original = to_jsonb(OLD.*) - excluded_cols;
        audit_row.diff = (to_jsonb(NEW.*) - audit_row.original) - excluded_cols;
        IF audit_row.diff = '{}'::jsonb THEN
            -- All changed fields are ignored. Skip this update.
            RETURN NULL;
        END IF;
    ELSIF (TG_OP = 'DELETE' AND TG_LEVEL = 'ROW') THEN
        audit_row.original = to_jsonb(OLD.*) - excluded_cols;
    ELSIF (TG_OP = 'INSERT' AND TG_LEVEL = 'ROW') THEN
        audit_row.original = to_jsonb(NEW.*) - excluded_cols;
    ELSIF (TG_LEVEL = 'STATEMENT' AND TG_OP IN ('INSERT','UPDATE','DELETE','TRUNCATE')) THEN
        audit_row.statement_only = 't';
    ELSE
        RAISE EXCEPTION '[audit.if_modified_func] - Trigger func added as trigger for unhandled case: %, %',TG_OP, TG_LEVEL;
        RETURN NULL;
    END IF;
    INSERT INTO audit.log VALUES (audit_row.*);
    RETURN NULL;
END;
$body$
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public;


COMMENT ON FUNCTION audit.if_modified_func() IS $body$
Track changes to a table at the statement and/or row level.

Optional parameters to trigger in CREATE TRIGGER call:

param 0: boolean, whether to log the query text. Default 't'.

param 1: text[], columns to ignore in updates. Default [].

         Updates to ignored cols are omitted from changed_fields.

         Updates with only ignored cols changed are not inserted
         into the audit log.

         Almost all the processing work is still done for updates
         that ignored. If you need to save the load, you need to use
         WHEN clause on the trigger instead.

         No warning or error is issued if ignored_cols contains columns
         that do not exist in the target table. This lets you specify
         a standard set of ignored columns.

There is no parameter to disable logging of values. Add this trigger as
a 'FOR EACH STATEMENT' rather than 'FOR EACH ROW' trigger if you do not
want to log row values.

Note that the user name logged is the login role for the session. The audit trigger
cannot obtain the active role because it is reset by the SECURITY DEFINER invocation
of the audit trigger its self.
$body$;

CREATE OR REPLACE FUNCTION audit.audit_table(
  target_table regclass,
  audit_rows boolean,
  audit_query_text boolean,
  ignored_cols text[]
)
RETURNS void AS $body$
DECLARE
  stm_targets text = 'INSERT OR UPDATE OR DELETE OR TRUNCATE';
  _q_txt text;
  _ignored_cols_snip text = '';
BEGIN
    EXECUTE 'DROP TRIGGER IF EXISTS audit_trigger_row ON ' || target_table::TEXT;
    EXECUTE 'DROP TRIGGER IF EXISTS audit_trigger_stm ON ' || target_table::TEXT;

    IF audit_rows THEN
        IF array_length(ignored_cols,1) > 0 THEN
            _ignored_cols_snip = ', ' || quote_literal(ignored_cols);
        END IF;
        _q_txt = 'CREATE TRIGGER audit_trigger_row AFTER INSERT OR UPDATE OR DELETE ON ' ||
                 target_table::TEXT ||
                 ' FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func(' ||
                 quote_literal(audit_query_text) || _ignored_cols_snip || ');';
        RAISE NOTICE '%',_q_txt;
        EXECUTE _q_txt;
        stm_targets = 'TRUNCATE';
    ELSE
    END IF;

    _q_txt = 'CREATE TRIGGER audit_trigger_stm AFTER ' || stm_targets || ' ON ' ||
             target_table ||
             ' FOR EACH STATEMENT EXECUTE PROCEDURE audit.if_modified_func('||
             quote_literal(audit_query_text) || ');';
    RAISE NOTICE '%',_q_txt;
    EXECUTE _q_txt;

END;
$body$
language 'plpgsql';

COMMENT ON FUNCTION audit.audit_table(regclass, boolean, boolean, text[]) IS $body$
Add auditing support to a table.

Arguments:
   target_table:     Table name, schema qualified if not on search_path
   audit_rows:       Record each row change, or only audit at a statement level
   audit_query_text: Record the text of the client query that triggered the audit event?
   ignored_cols:     Columns to exclude from update diffs, ignore updates that change only ignored cols.
$body$;

-- Pg doesn't allow variadic calls with 0 params, so provide a wrapper
CREATE OR REPLACE FUNCTION audit.audit_table(target_table regclass, audit_rows boolean, audit_query_text boolean) RETURNS void AS $body$
SELECT audit.audit_table($1, $2, $3, ARRAY[]::text[]);
$body$ LANGUAGE SQL;

-- And provide a convenience call wrapper for the simplest case
-- of row-level logging with no excluded cols and query logging enabled.
--
CREATE OR REPLACE FUNCTION audit.audit_table(target_table regclass) RETURNS void AS $body$
SELECT audit.audit_table($1, BOOLEAN 't', BOOLEAN 't');
$body$ LANGUAGE 'sql';

COMMENT ON FUNCTION audit.audit_table(regclass) IS $body$
Add auditing support to the given table. Row-level changes will be logged with full client query text. No cols are ignored.
$body$;
