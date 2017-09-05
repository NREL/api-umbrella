--
-- PostgreSQL database dump
--

-- Dumped from database version 9.6.4
-- Dumped by pg_dump version 9.6.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'SQL_ASCII';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: audit; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA audit;


--
-- Name: SCHEMA audit; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA audit IS 'Out-of-table audit/history logging tables and trigger functions';


--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET search_path = audit, pg_catalog;

--
-- Name: audit_table(regclass); Type: FUNCTION; Schema: audit; Owner: -
--

CREATE FUNCTION audit_table(target_table regclass) RETURNS void
    LANGUAGE sql
    AS $_$
SELECT audit.audit_table($1, BOOLEAN 't', BOOLEAN 't');
$_$;


--
-- Name: FUNCTION audit_table(target_table regclass); Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON FUNCTION audit_table(target_table regclass) IS '
Add auditing support to the given table. Row-level changes will be logged with full client query text. No cols are ignored.
';


--
-- Name: audit_table(regclass, boolean, boolean); Type: FUNCTION; Schema: audit; Owner: -
--

CREATE FUNCTION audit_table(target_table regclass, audit_rows boolean, audit_query_text boolean) RETURNS void
    LANGUAGE sql
    AS $_$
SELECT audit.audit_table($1, $2, $3, ARRAY[]::text[]);
$_$;


--
-- Name: audit_table(regclass, boolean, boolean, text[]); Type: FUNCTION; Schema: audit; Owner: -
--

CREATE FUNCTION audit_table(target_table regclass, audit_rows boolean, audit_query_text boolean, ignored_cols text[]) RETURNS void
    LANGUAGE plpgsql
    AS $$
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
$$;


--
-- Name: FUNCTION audit_table(target_table regclass, audit_rows boolean, audit_query_text boolean, ignored_cols text[]); Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON FUNCTION audit_table(target_table regclass, audit_rows boolean, audit_query_text boolean, ignored_cols text[]) IS '
Add auditing support to a table.

Arguments:
   target_table:     Table name, schema qualified if not on search_path
   audit_rows:       Record each row change, or only audit at a statement level
   audit_query_text: Record the text of the client query that triggered the audit event?
   ignored_cols:     Columns to exclude from update diffs, ignore updates that change only ignored cols.
';


--
-- Name: if_modified_func(); Type: FUNCTION; Schema: audit; Owner: -
--

CREATE FUNCTION if_modified_func() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO pg_catalog, public
    AS $$
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
$$;


--
-- Name: FUNCTION if_modified_func(); Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON FUNCTION if_modified_func() IS '
Track changes to a table at the statement and/or row level.

Optional parameters to trigger in CREATE TRIGGER call:

param 0: boolean, whether to log the query text. Default ''t''.

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
a ''FOR EACH STATEMENT'' rather than ''FOR EACH ROW'' trigger if you do not
want to log row values.

Note that the user name logged is the login role for the session. The audit trigger
cannot obtain the active role because it is reset by the SECURITY DEFINER invocation
of the audit trigger its self.
';


SET search_path = public, pg_catalog;

--
-- Name: current_app_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION current_app_user() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
      BEGIN
        RETURN current_setting('application.user');
      END;
      $$;


--
-- Name: jsonb_minus(jsonb, text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION jsonb_minus(json jsonb, keys text[]) RETURNS jsonb
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
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
$$;


--
-- Name: jsonb_minus(jsonb, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION jsonb_minus(arg1 jsonb, arg2 jsonb) RETURNS jsonb
    LANGUAGE sql
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

$$;


--
-- Name: next_api_backend_sort_order(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION next_api_backend_sort_order() RETURNS integer
    LANGUAGE plpgsql
    AS $$
      BEGIN
        RETURN (SELECT COALESCE(MAX(sort_order), 0) + 1 FROM api_backends);
      END;
      $$;


--
-- Name: set_updated(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION set_updated() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      BEGIN
        IF row(NEW.*) IS DISTINCT FROM row(OLD.*) THEN
          NEW.updated_at := (now() AT TIME ZONE 'UTC');
          NEW.updated_by := current_app_user();
          RETURN NEW;
        ELSE
          RETURN OLD;
        END IF;
      END;
      $$;


--
-- Name: -; Type: OPERATOR; Schema: public; Owner: -
--

CREATE OPERATOR - (
    PROCEDURE = jsonb_minus,
    LEFTARG = jsonb,
    RIGHTARG = text[]
);


--
-- Name: -; Type: OPERATOR; Schema: public; Owner: -
--

CREATE OPERATOR - (
    PROCEDURE = jsonb_minus,
    LEFTARG = jsonb,
    RIGHTARG = jsonb
);


SET search_path = audit, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: log; Type: TABLE; Schema: audit; Owner: -
--

CREATE TABLE log (
    id bigint NOT NULL,
    schema_name text NOT NULL,
    table_name text NOT NULL,
    relid oid NOT NULL,
    "session_user" text NOT NULL,
    action_tstamp_tx timestamp with time zone NOT NULL,
    action_tstamp_stm timestamp with time zone NOT NULL,
    action_tstamp_clk timestamp with time zone NOT NULL,
    transaction_id bigint,
    application_name text,
    application_user text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text NOT NULL,
    original jsonb,
    diff jsonb,
    statement_only boolean NOT NULL,
    CONSTRAINT log_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text])))
);


--
-- Name: TABLE log; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON TABLE log IS 'History of auditable actions on audited tables, from audit.if_modified_func()';


--
-- Name: COLUMN log.id; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN log.id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN log.schema_name; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN log.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN log.table_name; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN log.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN log.relid; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN log.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN log."session_user"; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN log."session_user" IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN log.action_tstamp_tx; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN log.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN log.action_tstamp_stm; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN log.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN log.action_tstamp_clk; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN log.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN log.transaction_id; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN log.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN log.application_name; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN log.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN log.client_addr; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN log.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN log.client_port; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN log.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN log.client_query; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN log.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN log.action; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN log.action IS 'Action type; I = insert, D = delete, U = update, T = truncate';


--
-- Name: COLUMN log.original; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN log.original IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN log.diff; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN log.diff IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN log.statement_only; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN log.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: log_id_seq; Type: SEQUENCE; Schema: audit; Owner: -
--

CREATE SEQUENCE log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: log_id_seq; Type: SEQUENCE OWNED BY; Schema: audit; Owner: -
--

ALTER SEQUENCE log_id_seq OWNED BY log.id;


SET search_path = public, pg_catalog;

--
-- Name: admin_groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE admin_groups (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    created_by character varying(255) DEFAULT current_app_user() NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    updated_by character varying(255) DEFAULT current_app_user() NOT NULL
);


--
-- Name: admin_groups_admin_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE admin_groups_admin_permissions (
    admin_group_id uuid NOT NULL,
    admin_permission_id character varying(50) NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    created_by character varying(255) DEFAULT current_app_user() NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    updated_by character varying(255) DEFAULT current_app_user() NOT NULL
);


--
-- Name: admin_groups_admins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE admin_groups_admins (
    admin_group_id uuid NOT NULL,
    admin_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    created_by character varying(255) DEFAULT current_app_user() NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    updated_by character varying(255) DEFAULT current_app_user() NOT NULL
);


--
-- Name: admin_groups_api_scopes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE admin_groups_api_scopes (
    admin_group_id uuid NOT NULL,
    api_scope_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    created_by character varying(255) DEFAULT current_app_user() NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    updated_by character varying(255) DEFAULT current_app_user() NOT NULL
);


--
-- Name: admin_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE admin_permissions (
    id character varying(50) NOT NULL,
    name character varying(255) NOT NULL,
    display_order smallint NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL
);


--
-- Name: admins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE admins (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    username character varying(255) NOT NULL,
    email character varying(255),
    name character varying(255),
    notes text,
    superuser boolean DEFAULT false NOT NULL,
    authentication_token_hash character varying(64) NOT NULL,
    authentication_token_encrypted character varying(76) NOT NULL,
    authentication_token_encrypted_iv character varying(12) NOT NULL,
    current_sign_in_provider character varying(100),
    last_sign_in_provider character varying(100),
    password_hash character varying(60),
    reset_password_token_hash character varying(64),
    reset_password_sent_at timestamp with time zone,
    remember_created_at timestamp with time zone,
    sign_in_count integer DEFAULT 0 NOT NULL,
    current_sign_in_at timestamp with time zone,
    last_sign_in_at timestamp with time zone,
    current_sign_in_ip inet,
    last_sign_in_ip inet,
    failed_attempts integer DEFAULT 0 NOT NULL,
    unlock_token_hash character varying(64),
    locked_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    created_by character varying(255) DEFAULT current_app_user() NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    updated_by character varying(255) DEFAULT current_app_user() NOT NULL
);


--
-- Name: api_backend_http_headers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE api_backend_http_headers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    api_backend_settings_id uuid NOT NULL,
    header_type character varying(17) NOT NULL,
    sort_order integer NOT NULL,
    key character varying(255) NOT NULL,
    value character varying(255),
    created_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    created_by character varying(255) DEFAULT current_app_user() NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    updated_by character varying(255) DEFAULT current_app_user() NOT NULL,
    CONSTRAINT api_backend_http_headers_header_type_check CHECK (((header_type)::text = ANY ((ARRAY['request'::character varying, 'response_default'::character varying, 'response_override'::character varying])::text[])))
);


--
-- Name: api_backend_rewrites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE api_backend_rewrites (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    api_backend_id uuid NOT NULL,
    matcher_type character varying(5) NOT NULL,
    http_method character varying(7) NOT NULL,
    frontend_matcher character varying(255) NOT NULL,
    backend_replacement character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    created_by character varying(255) DEFAULT current_app_user() NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    updated_by character varying(255) DEFAULT current_app_user() NOT NULL,
    CONSTRAINT api_backend_rewrites_http_method_check CHECK (((http_method)::text = ANY ((ARRAY['any'::character varying, 'GET'::character varying, 'POST'::character varying, 'PUT'::character varying, 'DELETE'::character varying, 'HEAD'::character varying, 'TRACE'::character varying, 'OPTIONS'::character varying, 'CONNECT'::character varying, 'PATCH'::character varying])::text[]))),
    CONSTRAINT api_backend_rewrites_matcher_type_check CHECK (((matcher_type)::text = ANY ((ARRAY['route'::character varying, 'regex'::character varying])::text[])))
);


--
-- Name: api_backend_servers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE api_backend_servers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    api_backend_id uuid NOT NULL,
    host character varying(255) NOT NULL,
    port integer NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    created_by character varying(255) DEFAULT current_app_user() NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    updated_by character varying(255) DEFAULT current_app_user() NOT NULL
);


--
-- Name: api_backend_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE api_backend_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    api_backend_id uuid,
    api_backend_sub_url_settings_id uuid,
    append_query_string character varying(255),
    http_basic_auth character varying(255),
    require_https character varying(23),
    require_https_transition_start_at timestamp with time zone,
    disable_api_key boolean DEFAULT false NOT NULL,
    api_key_verification_level character varying(16),
    api_key_verification_transition_start_at timestamp with time zone,
    required_roles_override boolean DEFAULT false NOT NULL,
    allowed_ips inet[],
    allowed_referers character varying(500)[],
    pass_api_key_header character varying(255),
    pass_api_key_query_param character varying(255),
    rate_limit_mode character varying(9),
    anonymous_rate_limit_behavior character varying(11),
    authenticated_rate_limit_behavior character varying(12),
    error_templates jsonb,
    error_data jsonb,
    created_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    created_by character varying(255) DEFAULT current_app_user() NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    updated_by character varying(255) DEFAULT current_app_user() NOT NULL,
    CONSTRAINT api_backend_settings_anonymous_rate_limit_behavior_check CHECK (((anonymous_rate_limit_behavior)::text = ANY ((ARRAY['ip_fallback'::character varying, 'ip_only'::character varying])::text[]))),
    CONSTRAINT api_backend_settings_api_key_verification_level_check CHECK (((api_key_verification_level)::text = ANY ((ARRAY['none'::character varying, 'transition_email'::character varying, 'required_email'::character varying])::text[]))),
    CONSTRAINT api_backend_settings_authenticated_rate_limit_behavior_check CHECK (((authenticated_rate_limit_behavior)::text = ANY ((ARRAY['all'::character varying, 'api_key_only'::character varying])::text[]))),
    CONSTRAINT api_backend_settings_rate_limit_mode_check CHECK (((rate_limit_mode)::text = ANY ((ARRAY['unlimited'::character varying, 'custom'::character varying])::text[]))),
    CONSTRAINT api_backend_settings_require_https_check CHECK (((require_https)::text = ANY ((ARRAY['required_return_error'::character varying, 'transition_return_error'::character varying, 'optional'::character varying])::text[]))),
    CONSTRAINT parent_id_not_null CHECK ((((api_backend_id IS NOT NULL) AND (api_backend_sub_url_settings_id IS NULL)) OR ((api_backend_id IS NULL) AND (api_backend_sub_url_settings_id IS NOT NULL))))
);


--
-- Name: api_backend_settings_required_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE api_backend_settings_required_roles (
    api_backend_settings_id uuid NOT NULL,
    api_role_id character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    created_by character varying(255) DEFAULT current_app_user() NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    updated_by character varying(255) DEFAULT current_app_user() NOT NULL
);


--
-- Name: api_backend_sub_url_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE api_backend_sub_url_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    api_backend_id uuid NOT NULL,
    http_method character varying(7) NOT NULL,
    regex character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    created_by character varying(255) DEFAULT current_app_user() NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    updated_by character varying(255) DEFAULT current_app_user() NOT NULL,
    CONSTRAINT api_backend_sub_url_settings_http_method_check CHECK (((http_method)::text = ANY ((ARRAY['any'::character varying, 'GET'::character varying, 'POST'::character varying, 'PUT'::character varying, 'DELETE'::character varying, 'HEAD'::character varying, 'TRACE'::character varying, 'OPTIONS'::character varying, 'CONNECT'::character varying, 'PATCH'::character varying])::text[])))
);


--
-- Name: api_backend_url_matches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE api_backend_url_matches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    api_backend_id uuid NOT NULL,
    frontend_prefix character varying(255) NOT NULL,
    backend_prefix character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    created_by character varying(255) DEFAULT current_app_user() NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    updated_by character varying(255) DEFAULT current_app_user() NOT NULL
);


--
-- Name: api_backends; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE api_backends (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255) NOT NULL,
    sort_order integer DEFAULT next_api_backend_sort_order() NOT NULL,
    backend_protocol character varying(5) NOT NULL,
    frontend_host character varying(255) NOT NULL,
    backend_host character varying(255),
    balance_algorithm character varying(11) NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    created_by character varying(255) DEFAULT current_app_user() NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    updated_by character varying(255) DEFAULT current_app_user() NOT NULL,
    CONSTRAINT api_backends_backend_protocol_check CHECK (((backend_protocol)::text = ANY ((ARRAY['http'::character varying, 'https'::character varying])::text[]))),
    CONSTRAINT api_backends_balance_algorithm_check CHECK (((balance_algorithm)::text = ANY ((ARRAY['round_robin'::character varying, 'least_conn'::character varying, 'ip_hash'::character varying])::text[])))
);


--
-- Name: api_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE api_roles (
    id character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    created_by character varying(255) DEFAULT current_app_user() NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    updated_by character varying(255) DEFAULT current_app_user() NOT NULL
);


--
-- Name: api_scopes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE api_scopes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(255) NOT NULL,
    host character varying(255) NOT NULL,
    path_prefix character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    created_by character varying(255) DEFAULT current_app_user() NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    updated_by character varying(255) DEFAULT current_app_user() NOT NULL
);


--
-- Name: api_user_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE api_user_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    api_user_id uuid NOT NULL,
    rate_limit_mode character varying(9),
    allowed_ips inet[],
    allowed_referers character varying(500)[],
    created_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    created_by character varying(255) DEFAULT current_app_user() NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    updated_by character varying(255) DEFAULT current_app_user() NOT NULL,
    CONSTRAINT api_user_settings_rate_limit_mode_check CHECK (((rate_limit_mode)::text = ANY ((ARRAY['unlimited'::character varying, 'custom'::character varying])::text[])))
);


--
-- Name: api_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE api_users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    api_key_hash character varying(64) NOT NULL,
    api_key_encrypted character varying(76) NOT NULL,
    api_key_encrypted_iv character varying(12) NOT NULL,
    api_key_prefix character varying(10) NOT NULL,
    email character varying(255) NOT NULL,
    email_verified boolean DEFAULT false NOT NULL,
    first_name character varying(255),
    last_name character varying(255),
    use_description character varying(2000),
    user_metadata jsonb,
    registration_ip inet,
    registration_source character varying(255),
    registration_user_agent character varying(1000),
    registration_referer character varying(1000),
    registration_origin character varying(1000),
    throttle_by_ip boolean DEFAULT false NOT NULL,
    disabled_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    created_by character varying(255) DEFAULT current_app_user() NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    updated_by character varying(255) DEFAULT current_app_user() NOT NULL
);


--
-- Name: api_users_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE api_users_roles (
    api_user_id uuid NOT NULL,
    api_role_id character varying(255) NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    created_by character varying(255) DEFAULT current_app_user() NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    updated_by character varying(255) DEFAULT current_app_user() NOT NULL
);


--
-- Name: rate_limits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE rate_limits (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    api_backend_settings_id uuid,
    api_user_settings_id uuid,
    duration bigint NOT NULL,
    accuracy bigint NOT NULL,
    limit_by character varying(7) NOT NULL,
    limit_to bigint NOT NULL,
    distributed boolean DEFAULT false NOT NULL,
    response_headers boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    created_by character varying(255) DEFAULT current_app_user() NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    updated_by character varying(255) DEFAULT current_app_user() NOT NULL,
    CONSTRAINT rate_limits_limit_by_check CHECK (((limit_by)::text = ANY ((ARRAY['ip'::character varying, 'api_key'::character varying])::text[]))),
    CONSTRAINT settings_id_not_null CHECK ((((api_backend_settings_id IS NOT NULL) AND (api_user_settings_id IS NULL)) OR ((api_backend_settings_id IS NULL) AND (api_user_settings_id IS NOT NULL))))
);


--
-- Name: api_users_flattened; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW api_users_flattened AS
 SELECT u.id,
    u.api_key_hash,
    u.api_key_encrypted,
    u.api_key_encrypted_iv,
    u.api_key_prefix,
    u.email,
    u.email_verified,
    u.first_name,
    u.last_name,
    u.use_description,
    u.user_metadata,
    u.registration_ip,
    u.registration_source,
    u.registration_user_agent,
    u.registration_referer,
    u.registration_origin,
    u.throttle_by_ip,
    u.disabled_at,
    u.created_at,
    u.created_by,
    u.updated_at,
    u.updated_by,
    row_to_json(s.*) AS settings,
    ( SELECT json_agg(r.*) AS json_agg
           FROM rate_limits r
          WHERE (r.api_user_settings_id = s.id)) AS rate_limits,
    ARRAY( SELECT ar.api_role_id
           FROM api_users_roles ar
          WHERE (ar.api_user_id = s.id)) AS roles
   FROM (api_users u
     LEFT JOIN api_user_settings s ON ((u.id = s.api_user_id)));


--
-- Name: lapis_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE lapis_migrations (
    name character varying(255) NOT NULL
);


--
-- Name: published_config; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE published_config (
    id bigint NOT NULL,
    config jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    created_by character varying(255) DEFAULT current_app_user() NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    updated_by character varying(255) DEFAULT current_app_user() NOT NULL
);


--
-- Name: published_config_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE published_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: published_config_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE published_config_id_seq OWNED BY published_config.id;


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE sessions (
    id character varying(40) NOT NULL,
    expires timestamp with time zone,
    encrypted_data text NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    created_by character varying(255) DEFAULT current_app_user() NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    updated_by character varying(255) DEFAULT current_app_user() NOT NULL
);


--
-- Name: website_backends; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE website_backends (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    frontend_host character varying(255) NOT NULL,
    backend_protocol character varying(5) NOT NULL,
    server_host character varying(255) NOT NULL,
    server_port integer NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    created_by character varying(255) DEFAULT current_app_user() NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    updated_by character varying(255) DEFAULT current_app_user() NOT NULL,
    CONSTRAINT website_backends_backend_protocol_check CHECK (((backend_protocol)::text = ANY ((ARRAY['http'::character varying, 'https'::character varying])::text[])))
);


SET search_path = audit, pg_catalog;

--
-- Name: log id; Type: DEFAULT; Schema: audit; Owner: -
--

ALTER TABLE ONLY log ALTER COLUMN id SET DEFAULT nextval('log_id_seq'::regclass);


SET search_path = public, pg_catalog;

--
-- Name: published_config id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY published_config ALTER COLUMN id SET DEFAULT nextval('published_config_id_seq'::regclass);


SET search_path = audit, pg_catalog;

--
-- Name: log log_pkey; Type: CONSTRAINT; Schema: audit; Owner: -
--

ALTER TABLE ONLY log
    ADD CONSTRAINT log_pkey PRIMARY KEY (id);


SET search_path = public, pg_catalog;

--
-- Name: admin_groups_admin_permissions admin_groups_admin_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY admin_groups_admin_permissions
    ADD CONSTRAINT admin_groups_admin_permissions_pkey PRIMARY KEY (admin_group_id, admin_permission_id);


--
-- Name: admin_groups_admins admin_groups_admins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY admin_groups_admins
    ADD CONSTRAINT admin_groups_admins_pkey PRIMARY KEY (admin_group_id, admin_id);


--
-- Name: admin_groups_api_scopes admin_groups_api_scopes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY admin_groups_api_scopes
    ADD CONSTRAINT admin_groups_api_scopes_pkey PRIMARY KEY (admin_group_id, api_scope_id);


--
-- Name: admin_groups admin_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY admin_groups
    ADD CONSTRAINT admin_groups_pkey PRIMARY KEY (id);


--
-- Name: admin_permissions admin_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY admin_permissions
    ADD CONSTRAINT admin_permissions_pkey PRIMARY KEY (id);


--
-- Name: admins admins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY admins
    ADD CONSTRAINT admins_pkey PRIMARY KEY (id);


--
-- Name: api_backend_http_headers api_backend_http_headers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY api_backend_http_headers
    ADD CONSTRAINT api_backend_http_headers_pkey PRIMARY KEY (id);


--
-- Name: api_backend_rewrites api_backend_rewrites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY api_backend_rewrites
    ADD CONSTRAINT api_backend_rewrites_pkey PRIMARY KEY (id);


--
-- Name: api_backend_servers api_backend_servers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY api_backend_servers
    ADD CONSTRAINT api_backend_servers_pkey PRIMARY KEY (id);


--
-- Name: api_backend_settings api_backend_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY api_backend_settings
    ADD CONSTRAINT api_backend_settings_pkey PRIMARY KEY (id);


--
-- Name: api_backend_settings_required_roles api_backend_settings_required_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY api_backend_settings_required_roles
    ADD CONSTRAINT api_backend_settings_required_roles_pkey PRIMARY KEY (api_backend_settings_id, api_role_id);


--
-- Name: api_backend_sub_url_settings api_backend_sub_url_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY api_backend_sub_url_settings
    ADD CONSTRAINT api_backend_sub_url_settings_pkey PRIMARY KEY (id);


--
-- Name: api_backend_url_matches api_backend_url_matches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY api_backend_url_matches
    ADD CONSTRAINT api_backend_url_matches_pkey PRIMARY KEY (id);


--
-- Name: api_backends api_backends_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY api_backends
    ADD CONSTRAINT api_backends_pkey PRIMARY KEY (id);


--
-- Name: api_roles api_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY api_roles
    ADD CONSTRAINT api_roles_pkey PRIMARY KEY (id);


--
-- Name: api_scopes api_scopes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY api_scopes
    ADD CONSTRAINT api_scopes_pkey PRIMARY KEY (id);


--
-- Name: api_user_settings api_user_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY api_user_settings
    ADD CONSTRAINT api_user_settings_pkey PRIMARY KEY (id);


--
-- Name: api_users api_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY api_users
    ADD CONSTRAINT api_users_pkey PRIMARY KEY (id);


--
-- Name: api_users_roles api_users_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY api_users_roles
    ADD CONSTRAINT api_users_roles_pkey PRIMARY KEY (api_user_id, api_role_id);


--
-- Name: lapis_migrations lapis_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY lapis_migrations
    ADD CONSTRAINT lapis_migrations_pkey PRIMARY KEY (name);


--
-- Name: published_config published_config_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY published_config
    ADD CONSTRAINT published_config_pkey PRIMARY KEY (id);


--
-- Name: rate_limits rate_limits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY rate_limits
    ADD CONSTRAINT rate_limits_pkey PRIMARY KEY (id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: website_backends website_backends_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY website_backends
    ADD CONSTRAINT website_backends_pkey PRIMARY KEY (id);


SET search_path = audit, pg_catalog;

--
-- Name: log_action_idx; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX log_action_idx ON log USING btree (action);


--
-- Name: log_action_tstamp_tx_stm_idx; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX log_action_tstamp_tx_stm_idx ON log USING btree (action_tstamp_stm);


--
-- Name: log_application_name_idx; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX log_application_name_idx ON log USING btree (application_name);


--
-- Name: log_application_user_idx; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX log_application_user_idx ON log USING btree (application_user);


--
-- Name: log_expr_idx; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX log_expr_idx ON log USING btree (((original ->> 'id'::text)));


--
-- Name: log_relid_idx; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX log_relid_idx ON log USING btree (relid);


--
-- Name: log_schema_name_table_name_idx; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX log_schema_name_table_name_idx ON log USING btree (schema_name, table_name);


SET search_path = public, pg_catalog;

--
-- Name: admin_permissions_display_order_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX admin_permissions_display_order_idx ON admin_permissions USING btree (display_order);


--
-- Name: admins_authentication_token_hash_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX admins_authentication_token_hash_idx ON admins USING btree (authentication_token_hash);


--
-- Name: admins_reset_password_token_hash_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX admins_reset_password_token_hash_idx ON admins USING btree (reset_password_token_hash);


--
-- Name: admins_unlock_token_hash_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX admins_unlock_token_hash_idx ON admins USING btree (unlock_token_hash);


--
-- Name: admins_username_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX admins_username_idx ON admins USING btree (username);


--
-- Name: api_backend_http_headers_api_backend_settings_id_header_typ_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX api_backend_http_headers_api_backend_settings_id_header_typ_idx ON api_backend_http_headers USING btree (api_backend_settings_id, header_type, sort_order);


--
-- Name: api_backend_settings_api_backend_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX api_backend_settings_api_backend_id_idx ON api_backend_settings USING btree (api_backend_id);


--
-- Name: api_backend_settings_api_backend_sub_url_settings_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX api_backend_settings_api_backend_sub_url_settings_id_idx ON api_backend_settings USING btree (api_backend_sub_url_settings_id);


--
-- Name: api_backends_sort_order_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_backends_sort_order_idx ON api_backends USING btree (sort_order);


--
-- Name: api_scopes_host_path_prefix_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX api_scopes_host_path_prefix_idx ON api_scopes USING btree (host, path_prefix);


--
-- Name: api_users_api_key_hash_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX api_users_api_key_hash_idx ON api_users USING btree (api_key_hash);


--
-- Name: admin_groups_admin_permissions admin_groups_admin_permissions_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER admin_groups_admin_permissions_updated_at BEFORE UPDATE ON admin_groups_admin_permissions FOR EACH ROW EXECUTE PROCEDURE set_updated();


--
-- Name: admin_groups_admins admin_groups_admins_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER admin_groups_admins_updated_at BEFORE UPDATE ON admin_groups_admins FOR EACH ROW EXECUTE PROCEDURE set_updated();


--
-- Name: admin_groups_api_scopes admin_groups_api_scopes_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER admin_groups_api_scopes_updated_at BEFORE UPDATE ON admin_groups_api_scopes FOR EACH ROW EXECUTE PROCEDURE set_updated();


--
-- Name: admin_groups admin_groups_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER admin_groups_updated_at BEFORE UPDATE ON admin_groups FOR EACH ROW EXECUTE PROCEDURE set_updated();


--
-- Name: admin_permissions admin_permissions_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER admin_permissions_updated_at BEFORE UPDATE ON admin_permissions FOR EACH ROW EXECUTE PROCEDURE set_updated();


--
-- Name: admins admins_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER admins_updated_at BEFORE UPDATE ON admins FOR EACH ROW EXECUTE PROCEDURE set_updated();


--
-- Name: api_backend_http_headers api_backend_http_headers_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER api_backend_http_headers_updated_at BEFORE UPDATE ON api_backend_http_headers FOR EACH ROW EXECUTE PROCEDURE set_updated();


--
-- Name: api_backend_rewrites api_backend_rewrites_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER api_backend_rewrites_updated_at BEFORE UPDATE ON api_backend_rewrites FOR EACH ROW EXECUTE PROCEDURE set_updated();


--
-- Name: api_backend_servers api_backend_servers_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER api_backend_servers_updated_at BEFORE UPDATE ON api_backend_servers FOR EACH ROW EXECUTE PROCEDURE set_updated();


--
-- Name: api_backend_settings_required_roles api_backend_settings_required_roles_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER api_backend_settings_required_roles_updated_at BEFORE UPDATE ON api_backend_settings_required_roles FOR EACH ROW EXECUTE PROCEDURE set_updated();


--
-- Name: api_backend_settings api_backend_settings_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER api_backend_settings_updated_at BEFORE UPDATE ON api_backend_settings FOR EACH ROW EXECUTE PROCEDURE set_updated();


--
-- Name: api_backend_sub_url_settings api_backend_sub_url_settings_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER api_backend_sub_url_settings_updated_at BEFORE UPDATE ON api_backend_sub_url_settings FOR EACH ROW EXECUTE PROCEDURE set_updated();


--
-- Name: api_backend_url_matches api_backend_url_matches_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER api_backend_url_matches_updated_at BEFORE UPDATE ON api_backend_url_matches FOR EACH ROW EXECUTE PROCEDURE set_updated();


--
-- Name: api_backends api_backends_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER api_backends_updated_at BEFORE UPDATE ON api_backends FOR EACH ROW EXECUTE PROCEDURE set_updated();


--
-- Name: api_roles api_roles_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER api_roles_updated_at BEFORE UPDATE ON api_roles FOR EACH ROW EXECUTE PROCEDURE set_updated();


--
-- Name: api_scopes api_scopes_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER api_scopes_updated_at BEFORE UPDATE ON api_scopes FOR EACH ROW EXECUTE PROCEDURE set_updated();


--
-- Name: api_user_settings api_user_settings_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER api_user_settings_updated_at BEFORE UPDATE ON api_user_settings FOR EACH ROW EXECUTE PROCEDURE set_updated();


--
-- Name: api_users_roles api_users_roles_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER api_users_roles_updated_at BEFORE UPDATE ON api_users_roles FOR EACH ROW EXECUTE PROCEDURE set_updated();


--
-- Name: api_users api_users_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER api_users_updated_at BEFORE UPDATE ON api_users FOR EACH ROW EXECUTE PROCEDURE set_updated();


--
-- Name: admins audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON admins FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: admin_permissions audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON admin_permissions FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: api_scopes audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON api_scopes FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: admin_groups audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON admin_groups FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: admin_groups_admin_permissions audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON admin_groups_admin_permissions FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: admin_groups_admins audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON admin_groups_admins FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: admin_groups_api_scopes audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON admin_groups_api_scopes FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: api_roles audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON api_roles FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: api_backends audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON api_backends FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: api_backend_rewrites audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON api_backend_rewrites FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: api_backend_servers audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON api_backend_servers FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: api_backend_sub_url_settings audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON api_backend_sub_url_settings FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: api_backend_url_matches audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON api_backend_url_matches FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: api_backend_settings audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON api_backend_settings FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: api_backend_settings_required_roles audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON api_backend_settings_required_roles FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: api_backend_http_headers audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON api_backend_http_headers FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: api_users audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON api_users FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: api_users_roles audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON api_users_roles FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: api_user_settings audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON api_user_settings FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: published_config audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON published_config FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: rate_limits audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON rate_limits FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: website_backends audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON website_backends FOR EACH ROW EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: admins audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON admins FOR EACH STATEMENT EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: admin_permissions audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON admin_permissions FOR EACH STATEMENT EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: api_scopes audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON api_scopes FOR EACH STATEMENT EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: admin_groups audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON admin_groups FOR EACH STATEMENT EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: admin_groups_admin_permissions audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON admin_groups_admin_permissions FOR EACH STATEMENT EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: admin_groups_admins audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON admin_groups_admins FOR EACH STATEMENT EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: admin_groups_api_scopes audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON admin_groups_api_scopes FOR EACH STATEMENT EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: api_roles audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON api_roles FOR EACH STATEMENT EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: api_backends audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON api_backends FOR EACH STATEMENT EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: api_backend_rewrites audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON api_backend_rewrites FOR EACH STATEMENT EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: api_backend_servers audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON api_backend_servers FOR EACH STATEMENT EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: api_backend_sub_url_settings audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON api_backend_sub_url_settings FOR EACH STATEMENT EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: api_backend_url_matches audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON api_backend_url_matches FOR EACH STATEMENT EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: api_backend_settings audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON api_backend_settings FOR EACH STATEMENT EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: api_backend_settings_required_roles audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON api_backend_settings_required_roles FOR EACH STATEMENT EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: api_backend_http_headers audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON api_backend_http_headers FOR EACH STATEMENT EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: api_users audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON api_users FOR EACH STATEMENT EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: api_users_roles audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON api_users_roles FOR EACH STATEMENT EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: api_user_settings audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON api_user_settings FOR EACH STATEMENT EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: published_config audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON published_config FOR EACH STATEMENT EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: rate_limits audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON rate_limits FOR EACH STATEMENT EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: website_backends audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON website_backends FOR EACH STATEMENT EXECUTE PROCEDURE audit.if_modified_func('true');


--
-- Name: published_config published_config_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER published_config_updated_at BEFORE UPDATE ON published_config FOR EACH ROW EXECUTE PROCEDURE set_updated();


--
-- Name: rate_limits rate_limits_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER rate_limits_updated_at BEFORE UPDATE ON rate_limits FOR EACH ROW EXECUTE PROCEDURE set_updated();


--
-- Name: sessions sessions_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sessions_updated_at BEFORE UPDATE ON sessions FOR EACH ROW EXECUTE PROCEDURE set_updated();


--
-- Name: website_backends website_backends_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER website_backends_updated_at BEFORE UPDATE ON website_backends FOR EACH ROW EXECUTE PROCEDURE set_updated();


--
-- Name: admin_groups_admin_permissions admin_groups_admin_permissions_admin_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY admin_groups_admin_permissions
    ADD CONSTRAINT admin_groups_admin_permissions_admin_group_id_fkey FOREIGN KEY (admin_group_id) REFERENCES admin_groups(id) ON DELETE CASCADE;


--
-- Name: admin_groups_admin_permissions admin_groups_admin_permissions_admin_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY admin_groups_admin_permissions
    ADD CONSTRAINT admin_groups_admin_permissions_admin_permission_id_fkey FOREIGN KEY (admin_permission_id) REFERENCES admin_permissions(id) ON DELETE CASCADE;


--
-- Name: admin_groups_admins admin_groups_admins_admin_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY admin_groups_admins
    ADD CONSTRAINT admin_groups_admins_admin_group_id_fkey FOREIGN KEY (admin_group_id) REFERENCES admin_groups(id) ON DELETE CASCADE;


--
-- Name: admin_groups_admins admin_groups_admins_admin_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY admin_groups_admins
    ADD CONSTRAINT admin_groups_admins_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE CASCADE;


--
-- Name: admin_groups_api_scopes admin_groups_api_scopes_admin_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY admin_groups_api_scopes
    ADD CONSTRAINT admin_groups_api_scopes_admin_group_id_fkey FOREIGN KEY (admin_group_id) REFERENCES admin_groups(id) ON DELETE CASCADE;


--
-- Name: admin_groups_api_scopes admin_groups_api_scopes_api_scope_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY admin_groups_api_scopes
    ADD CONSTRAINT admin_groups_api_scopes_api_scope_id_fkey FOREIGN KEY (api_scope_id) REFERENCES api_scopes(id) ON DELETE CASCADE;


--
-- Name: api_backend_http_headers api_backend_http_headers_api_backend_settings_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY api_backend_http_headers
    ADD CONSTRAINT api_backend_http_headers_api_backend_settings_id_fkey FOREIGN KEY (api_backend_settings_id) REFERENCES api_backend_settings(id) ON DELETE CASCADE;


--
-- Name: api_backend_rewrites api_backend_rewrites_api_backend_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY api_backend_rewrites
    ADD CONSTRAINT api_backend_rewrites_api_backend_id_fkey FOREIGN KEY (api_backend_id) REFERENCES api_backends(id) ON DELETE CASCADE;


--
-- Name: api_backend_servers api_backend_servers_api_backend_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY api_backend_servers
    ADD CONSTRAINT api_backend_servers_api_backend_id_fkey FOREIGN KEY (api_backend_id) REFERENCES api_backends(id) ON DELETE CASCADE;


--
-- Name: api_backend_settings api_backend_settings_api_backend_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY api_backend_settings
    ADD CONSTRAINT api_backend_settings_api_backend_id_fkey FOREIGN KEY (api_backend_id) REFERENCES api_backends(id) ON DELETE CASCADE;


--
-- Name: api_backend_settings api_backend_settings_api_backend_sub_url_settings_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY api_backend_settings
    ADD CONSTRAINT api_backend_settings_api_backend_sub_url_settings_id_fkey FOREIGN KEY (api_backend_sub_url_settings_id) REFERENCES api_backend_sub_url_settings(id) ON DELETE CASCADE;


--
-- Name: api_backend_settings_required_roles api_backend_settings_required_role_api_backend_settings_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY api_backend_settings_required_roles
    ADD CONSTRAINT api_backend_settings_required_role_api_backend_settings_id_fkey FOREIGN KEY (api_backend_settings_id) REFERENCES api_backend_settings(id) ON DELETE CASCADE;


--
-- Name: api_backend_settings_required_roles api_backend_settings_required_roles_api_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY api_backend_settings_required_roles
    ADD CONSTRAINT api_backend_settings_required_roles_api_role_id_fkey FOREIGN KEY (api_role_id) REFERENCES api_roles(id) ON DELETE CASCADE;


--
-- Name: api_backend_sub_url_settings api_backend_sub_url_settings_api_backend_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY api_backend_sub_url_settings
    ADD CONSTRAINT api_backend_sub_url_settings_api_backend_id_fkey FOREIGN KEY (api_backend_id) REFERENCES api_backends(id) ON DELETE CASCADE;


--
-- Name: api_backend_url_matches api_backend_url_matches_api_backend_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY api_backend_url_matches
    ADD CONSTRAINT api_backend_url_matches_api_backend_id_fkey FOREIGN KEY (api_backend_id) REFERENCES api_backends(id) ON DELETE CASCADE;


--
-- Name: api_user_settings api_user_settings_api_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY api_user_settings
    ADD CONSTRAINT api_user_settings_api_user_id_fkey FOREIGN KEY (api_user_id) REFERENCES api_users(id) ON DELETE CASCADE;


--
-- Name: api_users_roles api_users_roles_api_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY api_users_roles
    ADD CONSTRAINT api_users_roles_api_role_id_fkey FOREIGN KEY (api_role_id) REFERENCES api_roles(id) ON DELETE CASCADE;


--
-- Name: api_users_roles api_users_roles_api_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY api_users_roles
    ADD CONSTRAINT api_users_roles_api_user_id_fkey FOREIGN KEY (api_user_id) REFERENCES api_users(id) ON DELETE CASCADE;


--
-- Name: rate_limits rate_limits_api_backend_settings_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY rate_limits
    ADD CONSTRAINT rate_limits_api_backend_settings_id_fkey FOREIGN KEY (api_backend_settings_id) REFERENCES api_backend_settings(id) ON DELETE CASCADE;


--
-- Name: rate_limits rate_limits_api_user_settings_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY rate_limits
    ADD CONSTRAINT rate_limits_api_user_settings_id_fkey FOREIGN KEY (api_user_settings_id) REFERENCES api_user_settings(id) ON DELETE CASCADE;


--
-- Name: public; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA public TO api_umbrella_app_user;


--
-- Name: admin_groups; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE admin_groups TO api_umbrella_app_user;


--
-- Name: admin_groups_admin_permissions; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE admin_groups_admin_permissions TO api_umbrella_app_user;


--
-- Name: admin_groups_admins; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE admin_groups_admins TO api_umbrella_app_user;


--
-- Name: admin_groups_api_scopes; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE admin_groups_api_scopes TO api_umbrella_app_user;


--
-- Name: admin_permissions; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE admin_permissions TO api_umbrella_app_user;


--
-- Name: admins; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE admins TO api_umbrella_app_user;


--
-- Name: api_backend_http_headers; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE api_backend_http_headers TO api_umbrella_app_user;


--
-- Name: api_backend_rewrites; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE api_backend_rewrites TO api_umbrella_app_user;


--
-- Name: api_backend_servers; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE api_backend_servers TO api_umbrella_app_user;


--
-- Name: api_backend_settings; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE api_backend_settings TO api_umbrella_app_user;


--
-- Name: api_backend_settings_required_roles; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE api_backend_settings_required_roles TO api_umbrella_app_user;


--
-- Name: api_backend_sub_url_settings; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE api_backend_sub_url_settings TO api_umbrella_app_user;


--
-- Name: api_backend_url_matches; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE api_backend_url_matches TO api_umbrella_app_user;


--
-- Name: api_backends; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE api_backends TO api_umbrella_app_user;


--
-- Name: api_roles; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE api_roles TO api_umbrella_app_user;


--
-- Name: api_scopes; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE api_scopes TO api_umbrella_app_user;


--
-- Name: api_user_settings; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE api_user_settings TO api_umbrella_app_user;


--
-- Name: api_users; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE api_users TO api_umbrella_app_user;


--
-- Name: api_users_roles; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE api_users_roles TO api_umbrella_app_user;


--
-- Name: rate_limits; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE rate_limits TO api_umbrella_app_user;


--
-- Name: api_users_flattened; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE api_users_flattened TO api_umbrella_app_user;


--
-- Name: lapis_migrations; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE lapis_migrations TO api_umbrella_app_user;


--
-- Name: published_config; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE published_config TO api_umbrella_app_user;


--
-- Name: published_config_id_seq; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,UPDATE ON SEQUENCE published_config_id_seq TO api_umbrella_app_user;


--
-- Name: sessions; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE sessions TO api_umbrella_app_user;


--
-- Name: website_backends; Type: ACL; Schema: public; Owner: -
--

GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE website_backends TO api_umbrella_app_user;


--
-- PostgreSQL database dump complete
--

