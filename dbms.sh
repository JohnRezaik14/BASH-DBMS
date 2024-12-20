#!/bin/bash

# Get script directory for proper path resolution
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check and create databases directory
if [ ! -d "$DB_BASE_DIR" ]; then
    echo "Creating databases directory..."
    if ! mkdir -p "$DB_BASE_DIR"; then
        echo "Error: Failed to create databases directory at $DB_BASE_DIR"
        echo "Please check permissions and try again."
        exit 1
    fi
elif [ ! -w "$DB_BASE_DIR" ]; then
    echo "Error: Cannot write to databases directory at $DB_BASE_DIR"
    echo "Please check permissions and try again."
    exit 1
fi

# Add debug output
set -x  # Enable debug mode temporarily

# Source library files using absolute paths
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/tableServices.sh"
source "$SCRIPT_DIR/lib/dataServices.sh"

# Verify functions are loaded
type insert_into_table >/dev/null 2>&1 || { echo "insert_into_table not loaded"; exit 1; }
type select_from_table >/dev/null 2>&1 || { echo "select_from_table not loaded"; exit 1; }
type delete_from_table >/dev/null 2>&1 || { echo "delete_from_table not loaded"; exit 1; }

set +x  # Disable debug mode

# Function to create database
create_database() {
    db_name=$(get_user_input "Enter database name: ")
    
    # Validate database name
    if ! validate_name "$db_name"; then
        handle_error "Invalid database name. Use letters, numbers and underscores only"
        return 1
    fi
    
    # Create full path
    local db_path="$DB_BASE_DIR/$db_name"
    
    # Check if database already exists
    if [ -d "$db_path" ]; then
        handle_error "Database already exists!"
        return 1
    fi
    
    # Try to create database directory
    if mkdir -p "$db_path" 2>/dev/null; then
        show_success "Database $db_name created successfully!"
        return 0
    else
        handle_error "Failed to create database. Permission denied."
        return 1
    fi
}

# Function to list databases
list_databases() {
    clear
    if check_exists "$DB_BASE_DIR"; then
        echo "=== Available Databases ==="
        echo "----------------------------------------"
        find "$DB_BASE_DIR" -maxdepth 1 -type d -printf "| %f\n" | tail -n +2
        echo "----------------------------------------"
        echo "Press Enter to continue..."
        read -r
    else
        handle_error "No databases found."
        echo "Press Enter to continue..."
        read -r
    fi
    clear
}

# Function to drop database
drop_database() {
    clear
    if check_exists "$DB_BASE_DIR"; then
        echo "=== Available Databases ==="
        echo "----------------------------------------"
        find "$DB_BASE_DIR" -maxdepth 1 -type d -printf "| %f\n" | tail -n +2
        echo "----------------------------------------"
        
        db_name=$(get_user_input "Enter database name to drop (or type 'cancel' to return): ")
        
        if [ "$db_name" = "cancel" ]; then
            return
        elif [ -d "$DB_BASE_DIR/$db_name" ]; then
            confirm=$(get_user_input "Are you sure you want to drop '$db_name'? (yes/no): ")
            if [ "$confirm" = "yes" ]; then
                rm -r "$DB_BASE_DIR/$db_name"
                show_success "Database $db_name dropped successfully!"
            else
                handle_error "Operation cancelled"
            fi
        else
            handle_error "Database does not exist!"
        fi
    else
        handle_error "No databases found."
    fi
    sleep 2
    clear
}

# Function to connect to database
connect_to_database() {
    while true; do
        clear
        if check_exists "$DB_BASE_DIR"; then
            echo "=== Available Databases ==="
            echo "----------------------------------------"
            find "$DB_BASE_DIR" -maxdepth 1 -type d -printf "| %f\n" | tail -n +2
            echo "----------------------------------------"
            
            db_name=$(get_user_input "Enter database name to connect (or press Enter to return): ")
            
            if [ -z "$db_name" ] || [ "$db_name" = "" ]; then
                clear
                break
            elif check_exists "$DB_BASE_DIR/$db_name"; then
                show_success "Connecting to database: $db_name"
                sleep 1
                # Remove cd commands, use full paths instead
                table_menu "$db_name"
                break
            else
                handle_error "Database does not exist."
                sleep 2
            fi
        else
            handle_error "No databases found."
            sleep 2
            break
        fi
    done
}

# Function to display table operations menu
table_menu() {
    local db_name=$1
    while true; do
    clear
        echo "################################# Connected to Database: $db_name ###############################"
        echo "1) Create Table       3) Drop Table        5) Select From Table  7) Update Table"
        echo "2) List Tables        4) Insert into Table 6) Delete From Table  8) Back to Main Menu"
        echo "                                                                 9) Exit"
        
        choice=$(get_user_input "Please enter your choice: ")

        case $choice in
            1) create_table "$db_name" ;;
            2) list_tables "$db_name" ;;
            3) drop_table "$db_name" ;;
            4) 
                if ! insert_into_table "$db_name"; then
                    sleep 2
                fi
                ;;
            5) 
                if ! select_from_table "$db_name"; then
                    sleep 2
                fi
                ;;
            6) 
                if ! delete_from_table "$db_name"; then
                    sleep 2
                fi
                ;;
            7) update_table "$db_name" ;;
            8) clear; break ;;
            9) echo "Goodbye!"; exit 0 ;;
            *) handle_error "Invalid option" ;;
        esac
        clear
    done
}

# Main menu function
main_menu() {
    while true; do
        clear
        echo "=== Database Management System ==="
        echo "1. Create Database"
        echo "2. List Databases"
        echo "3. Connect To Database"
        echo "4. Drop Database"
        echo "5. Exit"
        echo "Enter your choice:"
        read choice

        case $choice in
            1) create_database ;;
            2) list_databases ;;
            3) connect_to_database ;;
            4) drop_database ;;
            5) echo "Goodbye!"; exit 0 ;;
            *) handle_error "Invalid option" ;;
        esac
    done
}

# Clean up old database structure if exists
# cleanup_old_structure() {
#     if [ -d "$DB_BASE_DIR/data/databases" ]; then
#         mv "$DB_BASE_DIR/data/databases"/* "$DB_BASE_DIR/" 2>/dev/null
#         rm -rf "$DB_BASE_DIR/data"
#     fi
# }

# Create base directory and start the application
# cleanup_old_structure
main_menu