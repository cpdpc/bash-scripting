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

# Check if the input text file is provided
if [ $# -ne 1 ]; then
  echo "Usage: $0 <input_file>"
  exit 1
fi

# Read the input file
INPUT_FILE=$1

# Check if the input text file exists
if [ ! -f $INPUT_FILE ]; then
  echo "Usernames and groups text file not found!"
  exit 1
fi

# Log messages helper function
log_message() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" | tee -a $LOG_FILE
}

# Generate random passwords helper function
generate_password() {
  tr -dc A-Za-z0-9 </dev/urandom | head -c 12 ; echo ''
}

while IFS=';' read -r username groups; do
  # Remove leading and trailing whitespaces
  username=$(echo $username | xargs)
  groups=$(echo $groups | xargs)

  if id "$username" &>/dev/null; then
    log_message "User $username already exists. Skipping..."
    continue
  fi

  # Create a personal group for the user
  groupadd $username
  if [ $? -ne 0 ]; then
    log_message "Failed to create group $username."
    continue
  fi
  log_message "Group $username created successfully."

  # Create user and add to personal group
  useradd -m -g $username -s /bin/bash $username
  if [ $? -ne 0 ]; then
    log_message "Failed to create user $username."
    continue
  fi
  log_message "User $username created successfully."

  # Create additional groups if they don't exist and add user to groups
  IFS=',' read -ra group_array <<< "$groups"
  for group in "${group_array[@]}"; do
    group=$(echo $group | xargs)
    if [ -z "$group" ]; then
      continue
    fi
    if ! getent group $group >/dev/null; then
      groupadd $group
      if [ $? -ne 0 ]; then
                log_message "Failed to create group $group."
                continue
      fi
      log_message "Group $group created successfully."
    fi
    usermod -aG $group $username
    log_message "User $username added to group $group."
  done

    # Set up home directory permissions
    chmod 700 /home/$username
    chown $username:$username /home/$username
    log_message "Permissions set for home directory of $username."

    # Generate and store random passwords for each user in the password file
    password=$(generate_password)
    echo "$username:$password" | chpasswd
    echo "$username:$password" >> $PASSWORD_FILE
    log_message "Generated password for '$username': $password"

done < "$INPUT_FILE"

log_message "User and group creation process completed."
