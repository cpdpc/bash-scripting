#echo "Linux User Creation Bash Script Task"

# path to log all actions
#USER_LOGS = /var/log/user_management.log

# path to store generated passwords
#PASSWORDS = /var/secure/user_passwords.txt

#!/bin/bash

echo "Linux User Creation Bash Script Task"

# Define log file path
LOG_FILE="/var/log/user_management.log"
# Define secure password storage path
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Function to create user with error handling
create_user() {
  username="$1"
  groups="$2"

  # Check if user already exists
  if id "$username" &> /dev/null; then
    echo "Warning: User '$username' already exists." >> "$LOG_FILE"
    # Logic to handle existing user (e.g., append number)
    read -p "User already exists. Append number (y/n)? " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
      username="${username}_1"
    fi
    return 1
  fi

  echo "Checking if user group exists"
  
  # Check if user's personal group exists
  if ! grep -q "^$username:" /etc/group; then
    groupadd "$username" >> "$LOG_FILE" 2>&1
    echo "User group created"
  else
    echo "Group '$username' already exists." >> "$LOG_FILE"
  fi
  
  echo "Setting ownership permissions"
  # Create user with home directory and set ownership/permissions
  useradd -m -g "$username" -s /bin/bash "$username" >> "$LOG_FILE" 2>&1
  chown -R "$username:$username" "/home/$username" >> "$LOG_FILE" 2>&1
  chmod 701 "/home/$username" >> "$LOG_FILE" 2>&1

  echo "Generating user passwords"
  # Generate random password and store securely
  password=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9!@#$%^&*()_+-=[]{}|;:,./<>?')
  echo "$username,$password" >> "$PASSWORD_FILE"
  echo "Generated password for '$username': $password" >> "$LOG_FILE"

  # Set user password using chpasswd
  echo "$password" | chpasswd <<< "$username" >> "$LOG_FILE" 2>&1

  echo "Adding users to additional groups (if any)"
  # Add user to additional groups (if any)
  IFS=',' read -r -a user_groups <<< "$groups"
  for group in "${user_groups[@]}"; do
    if ! grep -q "^$group:" /etc/group; then
      echo "Warning: Group '$group' does not exist for user '$username'." >> "$LOG_FILE"
    else
      usermod -a -G "$group" "$username" >> "$LOG_FILE" 2>&1
    fi
  done

  echo "Successfully created user '$username' in group '$username'." >> "$LOG_FILE"
}

# Check for input file argument
if [ $# -ne 1 ]; then
  echo "Usage: $0 <user_data_file>"
  exit 1
fi

# Check if user has root privileges
if [[ $EUID -ne 0 ]]; then
  echo "This script requires root privileges."
  exit 1
fi

echo "Clearing log file"
# Clear log file before starting
> "$LOG_FILE"

# Read user data file line by line
while IFS=';' read -r username groups; do
  # Remove leading/trailing whitespace from username and groups
  username="${username##* }"
  username="${username%% *}"
  groups="${groups##* }"
  groups="${groups%% *}"
  
  create_user "$username" "$groups"
done < "$1"

echo "User creation completed. See log file '$LOG_FILE' for details."

# Set secure permissions on password file (only owner can read)
chmod 600 "$PASSWORD_FILE"
