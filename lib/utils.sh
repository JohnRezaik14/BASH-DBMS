#!/bin/bash

source ./config.sh

# Error handling function
handle_error() {
    local error_message="$1"
    echo -e "${RED}Error: ${error_message}${NC}"
    sleep 2
}

# Success message function
show_success() {
    local message="$1"
    echo -e "${GREEN}${message}${NC}"
    sleep 1
}

# Input validation function
validate_name() {
    local input="$1"
    if [[ ! $input =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
        return 1
    fi
    return 0
}

# Check if database/table exists
check_exists() {
    local path="$1"
    if [ ! -e "$path" ]; then
        return 1
    fi
    return 0
}

# Add this new function
check_permissions() {
    local dir="$1"
    if ! [ -w "$(dirname "$dir")" ]; then
        handle_error "Permission denied. Cannot write to directory: $(dirname "$dir")"
        return 1
    fi
    return 0
}

# Validate datatype
validate_datatype() {
    local datatype=$1
    local value=$2

    case $datatype in
        "string") 
            return 0 
            ;;
        "int") 
            [[ $value =~ ^[0-9]+$ ]] && return 0
            ;;
        "float") 
            [[ $value =~ ^[0-9]+\.[0-9]+$ ]] && return 0
            ;;
        "date")
            # Basic format check
            [[ $value =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && return 0
            ;;
        "email") 
            [[ $value =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] && return 0
            ;;
        *) 
            return 1
            ;;
    esac
    return 1
}

# Show available datatypes - more compatible version
show_datatypes() {
    echo "Available datatypes:"
    echo "----------------------------------------"
    local i
    for ((i=0; i<${#DATATYPE_NAMES[@]}; i++)); do
        printf "%-10s : %s\n" "${DATATYPE_NAMES[$i]}" "${DATATYPE_DESC[$i]}"
    done
    echo "----------------------------------------"
}

get_user_input() {
    local prompt=$1
    local allow_empty=${2:-false}  # Second parameter defaults to false
    local input=""
    
    while true; do
        read -p "$prompt" input
        if [ -z "$input" ] && [ "$allow_empty" = "false" ]; then
            handle_error "Input cannot be empty"
            sleep 1
        else
            break
        fi
    done
    echo "$input"
}

# Add helper function for date input
get_date_input() {
    local prompt=$1
    local value=""
    
    echo "Enter date in format YYYY-MM-DD"
    echo "Examples:"
    echo "  2024-01-15  (January 15, 2024)"
    echo "  2023-12-31  (December 31, 2023)"
    echo "  2000-02-29  (February 29, 2000 - leap year)"
    echo "Note: Year must be between 1900-2100"
    
    while true; do
        read -p "$prompt" value
        # Remove any quotes or parentheses and normalize separators
        value=$(echo "$value" | tr -d "'()\"" | tr '/' '-')
        
        if validate_datatype "date" "$value"; then
            echo "$value"
            return 0
        else
            handle_error "Invalid date format or value"
            echo "Please enter date in YYYY-MM-DD format"
            echo "Example: 2024-01-15"
        fi
    done
}
