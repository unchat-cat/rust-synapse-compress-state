#!/bin/sh
# Copyright 2020 -- Evilham <cvs@evilham.com>
# License intended: BSD 2-clause
#
# Only use at your own risk and after understanding the implications of what
# you are doing, with backups and understanding how the code works.

# Exit on failure
set -e


# This script is a helper so you can easily keep your database tidy.
#
# It performs exactly zero write operations on the database, that's your
# responsibility.
#
# It is relatively expensive on CPU and RAM, but it can and probably should
# run on a different machine, you can e.g. forward the postgresql port with
# something like: ssh matrix@matrix.example.org -NL 5432:localhost:5432
# 
# If you don't provide a ROOM_ID, one amongst the top 5 "offenders" is picked
# at random.


# Requirements:
# The state compressor, e.g.:
# https://github.com/matrix-org/rust-synapse-compress-state
COMPRESS_STATE="${COMPRESS_STATE:-./synapse-compress-state}"

# postgresql-client in form of psql
PSQL=${PSQL:-psql}

# Make sure you pass the environment var in a halfway secure way
# chpst(8) is a very good option
#
# This should include any authentication, see man 8 psql
# It is also required that special symbols in the password
# are percent encoded.
#
# This script requires read access to following tables:
#  - state_groups
#  - state_groups_edges
#  - state_groups_state
PSQLDBURI=${PSQLDBURI:-postgresql://matrix:password@localhost/synapse}

# Loosely based on:
# https://github.com/matrix-org/synapse/wiki#what-are-the-biggest-rooms-on-my-server
RANDOM_TOP5_ROOM="
WITH top5 as (
    SELECT room_id, COUNT(*) AS num_rows
    FROM state_groups_state
    GROUP BY room_id
    ORDER BY num_rows DESC
    LIMIT 5
)
SELECT top5.room_id
FROM top5
ORDER BY random()
LIMIT 1;"

# If you prefer so, you can specify ROOM_ID
if [ -z "${ROOM_ID}" ]; then
  echo "No ROOM_ID was specified, picking a big room at random..."
  ROOM_ID=$(${PSQL} -t --dbname "${PSQLDBURI}" --command "${RANDOM_TOP5_ROOM}")
fi

cat <<EOF
Calculating compressed state for "${ROOM_ID}"
This will take a good while!

EOF
${COMPRESS_STATE} -t -p "${PSQLDBURI}" -r "${ROOM_ID}" -o "${ROOM_ID}.sql"

cat <<EOF
This script is done with "${ROOM_ID}"

Now you can:
1. rsync "${ROOM_ID}.sql" to the database server
2. stop synapse
3. apply the generated file: psql < ${ROOM_ID}.sql
4. consider applying synapse janitor too:
   https://github.com/xwiki-labs/synapse_scripts/blob/master/synapse_janitor.sql
5. start synapse

Remember to have backups, understanding and good will.
EOF
