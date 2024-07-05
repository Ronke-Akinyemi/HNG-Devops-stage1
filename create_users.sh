#!/bin/bash

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Define the input file and log files
INPUT_FILE="user_lists.txt"
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Ensure /var/secure directory exists
mkdir -p /var/secure
chmod 700 /var/secure

# Clear previous log entries
> "$LOG_FILE"

# Function to generate a random password
generate_password() {
  local password_length=12
  tr -dc A-Za-z0-9 </dev/urandom | head -c $password_length
}

# Read the input file line by line
while IFS=';' read -r username groups; do
  # Remove leading and trailing whitespaces
  username=$(echo "$username" | xargs)
  groups=$(echo "$groups" | xargs)

  # Create user and personal group
  if id "$username" &>/dev/null; then
    echo "User $username already exists. Skipping..." | tee -a "$LOG_FILE"
  else
    # Create the user with a home directory
    useradd -m "$username" -s /bin/bash
    if [ $? -eq 0 ]; then
      echo "Created user $username" | tee -a "$LOG_FILE"

      # Create personal group with the same name as the username
      usermod -aG "$username" "$username"

      # Set the home directory permissions
      chmod 700 /home/"$username"
      chown "$username":"$username" /home/"$username"

      # Generate a random password
      password=$(generate_password)
      echo "$username:$password" | chpasswd

      # Store the password securely
      echo "$username:$password" >> "$PASSWORD_FILE"
      chmod 600 "$PASSWORD_FILE"

      echo "Password for $username stored securely" | tee -a "$LOG_FILE"
    else
      echo "Failed to create user $username" | tee -a "$LOG_FILE"
      continue
    fi
  fi

  # Create and add groups to the user
  IFS=',' read -r -a group_array <<< "$groups"
  for group in "${group_array[@]}"; do
    group=$(echo "$group" | xargs) # Remove leading and trailing whitespaces
    if [ -n "$group" ]; then
      if ! getent group "$group" &>/dev/null; then
        groupadd "$group"
        echo "Created group $group" | tee -a "$LOG_FILE"
      fi
      usermod -aG "$group" "$username"
      echo "Added $username to group $group" | tee -a "$LOG_FILE"
    fi
  done

done < "$INPUT_FILE"

echo "User creation process completed." | tee -a "$LOG_FILE"

