#!/bin/bash

# Database configuration
if [ -z "$DBMS_HOME" ]; then
    DBMS_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
DB_BASE_DIR="$DBMS_HOME/databases"
MAX_TABLE_NAME_LENGTH=30
MAX_COLUMN_COUNT=50
FIELD_SEPARATOR="|"

# Supported datatypes - using traditional array for compatibility
declare -a DATATYPE_NAMES=("string" "int" "float" "date" "email")
declare -a DATATYPE_DESC=(
    "Text data"
    "Integer numbers"
    "Decimal numbers"
    "Date (YYYY-MM-DD)"
    "Email address"
)

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color
