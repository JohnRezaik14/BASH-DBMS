# BASH-DBMS

BASH-DBMS is a Command Line Interface (CLI) based database management system implemented using Bash scripting. It provides fundamental database operations such as creating, listing, connecting to, and deleting databases, as well as managing tables within these databases.

## Purpose

The primary objective of BASH-DBMS is to offer a lightweight, file-based database management solution for educational purposes and simple data storage needs. It serves as a practical example of how Bash scripting can be utilized to manage data without relying on traditional database management systems.

## Features

- **Database Operations**:
  - Create new databases
  - List existing databases
  - Connect to a specific database
  - Delete databases

- **Table Operations**:
  - Create new tables within a connected database
  - List tables in the current database
  - Delete tables
  - Insert records into tables
  - Select and display records from tables
  - Update existing records
  - Delete records from tables

## Usage

### Prerequisites

Ensure that you have Bash installed on your system. BASH-DBMS is designed to run in a Unix-like environment.

### Installation

1. **Clone the Repository**:

   ```bash
   git clone https://github.com/JohnRezaik14/BASH-DBMS.git
   
2. **Navigate to the Project Directory:**:

   ```bash
    cd BASH-DBMS
   
3. **Set Permissions:**:

     ```bash
     chmod +x dbms.sh:
     chmod -R u+rx lib/

**Database Directory permissions:**:
 
       chmod -R u+rwx database_name/
 
4.Running the Application
  ```bash
      ./dbms.sh


  
