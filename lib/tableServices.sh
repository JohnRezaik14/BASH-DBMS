#!/bin/bash

create_table() {
    local db_name=$1
    table_name=$(get_user_input "Enter table name: ")
    
    # Validate table name
    if ! validate_name "$table_name"; then
        handle_error "Invalid table name. Use letters, numbers and underscores only"
        return 1
    fi
    # Ensure database directory exists
    if [ ! -d "$DB_BASE_DIR/$db_name" ]; then
        handle_error "Database directory not found"
        return 1
    fi
    
    read -p "Enter primary key column name: " pk_column
    
    # Ask for PK type
    echo "Primary Key options:"
    echo "1) Auto Increment"
    echo "2) Manual Input"
    pk_type=$(get_user_input "Choose primary key type (1/2): ")
    
    # Create files
    if ! touch "$DB_BASE_DIR/$db_name/${table_name}.data" "$DB_BASE_DIR/$db_name/${table_name}.meta"; then
        handle_error "Failed to create table files"
        return 1
    fi
    
    # Store PK info with type
    if [ "$pk_type" = "1" ]; then
        echo "Primary Key: $pk_column:auto" > "$DB_BASE_DIR/$db_name/${table_name}.meta"
        # Initialize auto-increment counter
        echo "1" > "$DB_BASE_DIR/$db_name/${table_name}.counter"
    else
        echo "Primary Key: $pk_column:manual" > "$DB_BASE_DIR/$db_name/${table_name}.meta"
    fi

    while true; do
        read -p "Enter column name (or 'done' to finish): " column_name
        if [ "$column_name" == "done" ]; then
            break
        fi
        
        show_datatypes
        while true; do
            read -p "Enter datatype for $column_name: " datatype
            datatype=$(echo "$datatype" | tr -d '[:space:]')  # Remove any whitespace
            if [[ -n "${DATATYPES[$datatype]}" ]]; then
                echo "$column_name: $datatype" >> "$DB_BASE_DIR/$db_name/${table_name}.meta"
                break
            else
                handle_error "Invalid datatype. Please choose from the list above"
            fi
        done
    done
    echo "Table '$table_name' created in database '$db_name'."
}

list_tables() {
    local db_name=$1
    echo "Tables in database '$db_name':"
    echo "----------------------------------------"
    if [ -d "$DB_BASE_DIR/$db_name" ]; then
        find "$DB_BASE_DIR/$db_name" -maxdepth 1 -name "*.data" -printf "| %f\n" | sed 's/\.data$//'
        echo "----------------------------------------"
    else
        handle_error "No tables found in database."
    fi
    echo "Press Enter to continue..."
    read -r
}

drop_table() {
    local db_name=$1
    list_tables "$db_name"
    table_name=$(get_user_input "Enter table name to drop: ")
    rm -f "$DB_BASE_DIR/$db_name/${table_name}.data"
    rm -f "$DB_BASE_DIR/$db_name/${table_name}.meta"
    echo "Table '$table_name' dropped from database '$db_name'."
}

update_table() {
    local db_name=$1
    list_tables "$db_name"
    table_name=$(get_user_input "Enter table name: ")

    # Get and show columns with numbers and types
    echo "Available columns:"
    echo "----------------------------------------"
    local pk_name=$(grep "Primary Key:" "$DB_BASE_DIR/$db_name/${table_name}.meta" | cut -d: -f2 | tr -d ' ')
    
    # Get columns and their types
    declare -A col_types
    while IFS=: read -r col_name col_type; do
        if [[ "$col_name" != "Primary Key"* ]]; then
            col_types["$col_name"]="${col_type## }"
        fi
    done < "$DB_BASE_DIR/$db_name/${table_name}.meta"

    # Get all columns in order including PK
    mapfile -t all_columns < <(
        echo "$pk_name"
        grep -v "Primary Key:" "$DB_BASE_DIR/$db_name/${table_name}.meta" | cut -d: -f1
    )

    # Display columns with types, starting from 1
    for ((i=0; i<${#all_columns[@]}; i++)); do
        if [ $i -eq 0 ]; then
            echo "$((i+1))) $pk_name (Primary Key)"
        else
            echo "$((i+1))) ${all_columns[$i]} (${col_types[${all_columns[$i]}]})"
        fi
    done
    echo "----------------------------------------"

    # Get condition details
    cond_col_num=$(get_user_input "Enter column number (1-${#all_columns[@]}): ")
    # Adjust column number to 0-based index
    ((cond_col_num--))
    
    if [ "$cond_col_num" -lt 0 ] || [ "$cond_col_num" -ge "${#all_columns[@]}" ]; then
        handle_error "Invalid column number"
        return 1
    fi

    echo "Available operators: = > < >= <= !="
    operator=$(get_user_input "Enter operator: ")
    cond_value=$(get_user_input "Enter value to compare with: ")

    # Validate operator
    case $operator in
        "="|">"|"<"|">="|"<="|"!=") ;;
        *) 
            handle_error "Invalid operator"
            return 1
            ;;
    esac

    # Get update details
    update_col_num=$(get_user_input "Enter column number to update (1-${#all_columns[@]}): ")
    # Adjust column number to 0-based index
    ((update_col_num--))
    
    if [ "$update_col_num" -lt 0 ] || [ "$update_col_num" -ge "${#all_columns[@]}" ]; then
        handle_error "Invalid column number"
        return 1
    fi

    # Get column type and validate new value
    update_col_name="${all_columns[$update_col_num]}"
    col_type="${col_types[$update_col_name]}"
    
    # Get and validate new value based on type
    while true; do
        echo "Enter new value for ${update_col_name} (${col_type})"
        if [ "$col_type" = "date" ]; then
            # Use date input helper function with proper cleanup
            value=$(echo "$value" | tr -d "'()\"" | tr '/' '-')
            echo "Enter date in format YYYY-MM-DD"
            echo "Examples:"
            echo "  2000-01-15  (January 15, 2000)"
            echo "  2004-12-30  (December 30, 2005)"
            new_value=$(get_user_input "Enter date: ")
            new_value=$(echo "$new_value" | tr -d "'()\"" | tr '/' '-')
        else
            new_value=$(get_user_input "Enter value: ")
        fi
        
        if validate_datatype "$col_type" "$new_value"; then
            break
        else
            handle_error "Invalid value for type $col_type"
            case $col_type in
                "int") echo "Expected: whole number (e.g., 42)" ;;
                "float") echo "Expected: decimal number (e.g., 3.14)" ;;
                "date") echo "Expected: YYYY-MM-DD (e.g., 2024-01-15)" ;;
                "email") echo "Expected: valid email (e.g., user@example.com)" ;;
                *) echo "Expected format: ${DATATYPES[$col_type]}" ;;
            esac
        fi
    done

    # Update with validation using 1-based column numbers for awk
    awk -v cond_col="$((cond_col_num+1))" \
        -v op="$operator" \
        -v cond_val="$cond_value" \
        -v update_col="$((update_col_num+1))" \
        -v new_val="$new_value" '
    BEGIN { 
        FS=OFS="|"
    }
    {
        match_condition = 0
        if (op == "=")  match_condition = ($cond_col == cond_val)
        if (op == ">")  match_condition = ($cond_col > cond_val)
        if (op == "<")  match_condition = ($cond_col < cond_val)
        if (op == ">=") match_condition = ($cond_col >= cond_val)
        if (op == "<=") match_condition = ($cond_col <= cond_val)
        if (op == "!=") match_condition = ($cond_col != cond_val)
        
        if (match_condition) {
            $update_col = new_val
        }
        print
    }' "$DB_BASE_DIR/$db_name/${table_name}.data" > "$DB_BASE_DIR/$db_name/${table_name}.tmp" && \
    mv "$DB_BASE_DIR/$db_name/${table_name}.tmp" "$DB_BASE_DIR/$db_name/${table_name}.data"

    show_success "Table '$table_name' in database '$db_name' updated."
    echo "Press Enter to continue..."
    read -r
}
