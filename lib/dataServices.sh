#!/bin/bash

# Add export to make functions available
export -f insert_into_table
export -f select_from_table
export -f delete_from_table

# Debug output
echo "Loading dataServices.sh"

insert_into_table() {
    local db_name=$1
    list_tables "$db_name"
    table_name=$(get_user_input "Enter table name: ")
    
    # Validate table exists
    if [ ! -f "$DB_BASE_DIR/$db_name/${table_name}.meta" ]; then
        handle_error "Table does not exist"
        return 1
    fi

    # Get PK info
    pk_info=$(grep "Primary Key:" "$DB_BASE_DIR/$db_name/${table_name}.meta")
    pk_name=$(echo "$pk_info" | cut -d: -f2 | cut -d" " -f2 | cut -d":" -f1)
    pk_type=$(echo "$pk_info" | cut -d: -f3)

    # Handle PK value
    if [ "$pk_type" = "auto" ]; then
        # Get and increment counter
        pk_value=$(<"$DB_BASE_DIR/$db_name/${table_name}.counter")
        echo $((pk_value + 1)) > "$DB_BASE_DIR/$db_name/${table_name}.counter"
    else
        # Manual PK input with validation
        while true; do
            pk_value=$(get_user_input "Enter value for primary key ($pk_name): ")
            # Check if PK already exists
            if grep -q "^${pk_value}|" "$DB_BASE_DIR/$db_name/${table_name}.data" 2>/dev/null; then
                handle_error "Primary key value already exists"
                continue
            fi
            break
        done
    fi

    # Get other columns
    record="$pk_value"
    mapfile -t columns < <(grep -v "Primary Key:" "$DB_BASE_DIR/$db_name/${table_name}.meta" | cut -d: -f1)
    
    # Get columns with their datatypes
    declare -A col_types
    while IFS=: read -r col_name col_type; do
        if [[ "$col_name" != "Primary Key"* ]]; then
            col_types["$col_name"]="${col_type## }"
        fi
    done < "$DB_BASE_DIR/$db_name/${table_name}.meta"
    
    # Build record with validation
    for col in "${columns[@]}"; do
        while true; do
            if [ "${col_types[$col]}" = "date" ]; then
                while true; do
                    read -p "Enter value for $col (YYYY-MM-DD): " value
                    # Clean up input and validate
                    value=$(echo "$value" | tr -d "'()\"" | tr '/' '-')
                    if [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                        year=${value:0:4}
                        month=${value:5:2}
                        day=${value:8:2}
                        
                        # Basic range validation
                        if [ "$month" -ge 1 ] && [ "$month" -le 12 ] && [ "$day" -ge 1 ] && [ "$day" -le 31 ]; then
                            break
                        fi
                    fi
                    handle_error "Invalid date format. Please use YYYY-MM-DD"
                done
            else
                value=$(get_user_input "Enter value for $col (${col_types[$col]}): ")
            fi
            
            if validate_datatype "${col_types[$col]}" "$value"; then
                break
            else
                handle_error "Invalid value for type ${col_types[$col]}"
                echo "Expected format: ${DATATYPES[${col_types[$col]}]}"
            fi
        done
        record+="|$value"
    done
    
    if ! echo "$record" >> "$DB_BASE_DIR/$db_name/${table_name}.data"; then
        handle_error "Failed to insert record"
        # Rollback counter if auto-increment
        [ "$pk_type" = "auto" ] && echo "$pk_value" > "$DB_BASE_DIR/$db_name/${table_name}.counter"
        return 1
    fi
    
    show_success "Record inserted successfully"
    echo "Press Enter to continue..."
    read -r
    return 0
}

select_from_table() {
    local db_name=$1
    list_tables "$db_name"
    table_name=$(get_user_input "Enter table name: ")
    
    if [ ! -f "$DB_BASE_DIR/$db_name/${table_name}.meta" ]; then
        handle_error "Table does not exist"
        return 1
    fi

    # Get all columns including PK
    local pk_name=$(grep "Primary Key:" "$DB_BASE_DIR/$db_name/${table_name}.meta" | cut -d: -f2 | tr -d ' ')
    mapfile -t all_columns < <(
        echo "$pk_name"
        grep -v "Primary Key:" "$DB_BASE_DIR/$db_name/${table_name}.meta" | cut -d: -f1
    )

    # Display columns with better formatting
    echo "Available columns:"
    echo "----------------------------------------"
    printf "%-4s %-20s %s\n" "Num" "Column Name" "Type"
    echo "----------------------------------------"
    printf "%-4s %-20s %s\n" "0" "$pk_name" "(Primary Key)"
    
    local column_num=1
    while IFS=: read -r col_name col_type; do
        if [[ "$col_name" != "Primary Key"* ]]; then
            printf "%-4s %-20s %s\n" "$column_num" "$col_name" "$col_type"
            ((column_num++))
        fi
    done < "$DB_BASE_DIR/$db_name/${table_name}.meta"
    echo "----------------------------------------"

    echo "Select options:"
    echo "1) Select all records"
    echo "2) Select with condition"
    choice=$(get_user_input "Enter your choice: ")

    case $choice in
        1)
            echo "----------------------------------------"
            # Print aligned column headers
            for ((i=0; i<${#all_columns[@]}; i++)); do
                printf "%-20s" "${all_columns[$i]}"
                [[ $i -lt $((${#all_columns[@]}-1)) ]] && echo -n "|"
            done
            echo
            echo "----------------------------------------"

            if [ -s "$DB_BASE_DIR/$db_name/${table_name}.data" ]; then
                while IFS='|' read -r -a values; do
                    for ((i=0; i<${#values[@]}; i++)); do
                        printf "%-20s" "${values[$i]}"
                        [[ $i -lt $((${#values[@]}-1)) ]] && echo -n "|"
                    done
                    echo
                done < "$DB_BASE_DIR/$db_name/${table_name}.data"
            else
                echo "No records found"
            fi
            ;;
        2)
            column_num=$(get_user_input "Enter column number from above list: ")
            if [[ $column_num =~ ^[0-9]+$ ]] && [ "$column_num" -lt "${#all_columns[@]}" ]; then
                selected_column="${all_columns[$column_num]}"
                value=$(get_user_input "Enter value for $selected_column: ")
                
                echo "----------------------------------------"
                echo "Matching records:"
                if [ -s "$DB_BASE_DIR/$db_name/${table_name}.data" ]; then
                    # Print aligned headers
                    for ((i=0; i<${#all_columns[@]}; i++)); do
                        printf "%-20s" "${all_columns[$i]}"
                        [[ $i -lt $((${#all_columns[@]}-1)) ]] && echo -n "|"
                    done
                    echo
                    echo "----------------------------------------"
                    # Print aligned data
                    awk -v col="$((column_num+1))" -v val="$value" '
                    BEGIN { FS=OFS="|" }
                    $col == val {
                        for(i=1; i<=NF; i++) {
                            printf "%-20s", $i
                            if(i<NF) printf "|"
                        }
                        printf "\n"
                    }' "$DB_BASE_DIR/$db_name/${table_name}.data"
                else
                    echo "No records found"
                fi
            else
                handle_error "Invalid column number"
                return 1
            fi
            ;;
        *)
            handle_error "Invalid option"
            return 1
            ;;
    esac
    echo "----------------------------------------"
    echo "Press Enter to continue..."
    read -r
}

delete_from_table() {
    local db_name=$1
    list_tables "$db_name"
    table_name=$(get_user_input "Enter table name: ")
    
    if [ ! -f "$DB_BASE_DIR/$db_name/${table_name}.meta" ]; then
        handle_error "Table does not exist"
        return 1
    fi

    # Get all columns including PK
    local pk_name=$(grep "Primary Key:" "$DB_BASE_DIR/$db_name/${table_name}.meta" | cut -d: -f2 | tr -d ' ')
    mapfile -t all_columns < <(
        echo "$pk_name"
        grep -v "Primary Key:" "$DB_BASE_DIR/$db_name/${table_name}.meta" | cut -d: -f1
    )

    echo "Available columns:"
    echo "----------------------------------------"
    echo "0) $pk_name (Primary Key)"
    grep -v "Primary Key:" "$DB_BASE_DIR/$db_name/${table_name}.meta" | cut -d: -f1 | nl -v 1
    echo "----------------------------------------"

    column_num=$(get_user_input "Enter column number from above list: ")
    if [[ ! $column_num =~ ^[0-9]+$ ]] || [ "$column_num" -ge "${#all_columns[@]}" ]; then
        handle_error "Invalid column number"
        return 1
    fi

    selected_column="${all_columns[$column_num]}"
    value=$(get_user_input "Enter value for $selected_column: ")

    if awk -v col="$((column_num+1))" -v val="$value" '
        BEGIN { FS=OFS="|" }
        $col != val { print }' "$DB_BASE_DIR/$db_name/${table_name}.data" > "$DB_BASE_DIR/$db_name/${table_name}.tmp"; then
        
        mv "$DB_BASE_DIR/$db_name/${table_name}.tmp" "$DB_BASE_DIR/$db_name/${table_name}.data"
        show_success "Records deleted successfully."
    else
        handle_error "Failed to delete records"
        rm -f "$DB_BASE_DIR/$db_name/${table_name}.tmp"
        return 1
    fi
    
    echo "Press Enter to continue..."
    read -r
}
