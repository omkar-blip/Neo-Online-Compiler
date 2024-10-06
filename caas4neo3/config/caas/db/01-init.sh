#!/bin/bash
set -e

echo "Starting... $POSTGRES_USER : $POSTGRES_PASSWORD : $POSTGRES_DB : $API_DB_USER : $API_DB_PASSWORD : $API_DB_DATABASE"

export PGPASSWORD=$POSTGRES_PASSWORD;
export TOKENVALS=$( cat $APP_DB_TOKENS );
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  SELECT 'CREATE DATABASE "$API_DB_DATABASE"'
      WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$API_DB_DATABASE')\gexec
  CREATE USER "$API_DB_USER" WITH PASSWORD '$API_DB_PASSWORD';
  ALTER USER "$API_DB_USER" WITH SUPERUSER;
  GRANT ALL PRIVILEGES ON DATABASE "$API_DB_DATABASE" TO "$API_DB_USER";
  COMMIT;
  \connect "$API_DB_DATABASE" "$API_DB_USER"
  BEGIN;
    DROP TABLE IF EXISTS "Tokens";
    CREATE TABLE "Tokens" (
	  "Id" SERIAL PRIMARY KEY,
      "Guid" UUID NOT NULL,
      "Token" VARCHAR(500) NOT NULL,
      "ExpirationDate" DATE NOT NULL,
      "Active" BOOLEAN NOT NULL,
      "ClientId" INT,
      "Description" VARCHAR(200),
      "Rates" INT
	);
	CREATE INDEX idx_token_id ON "Tokens" ("Id");
  COMMIT;
  BEGIN;
    INSERT INTO "Tokens"("Guid", "Token", "ExpirationDate", "Active", "ClientId", "Description", "Rates")
    VALUES
    $TOKENVALS
  COMMIT;
EOSQL
