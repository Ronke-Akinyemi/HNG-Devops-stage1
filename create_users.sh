#!/bin/bash

# Function to generate random password
generate_password() {
    openssl rand -base64 12
}

# Input file
input_file="user_lists.txt"

# Loop through each line in the input file
while IFS=';' read -r username groups; do
    # Check if username already exists
    if id "$username" &>/dev/null; then
        echo "User $username already exists. Skipping."
        echo "$(date) - User $username already exists. Skipping." >> /var/log/user_management.log
        continue
    fi

    # Create user and primary group
    useradd -m -s /bin/bash "$username"
    usermod -aG "$username" "$username"

    # Create additional groups
    IFS=',' read -ra groups_array <<< "$groups"
    for group in "${groups_array[@]}"; do
        groupadd "$group"
        usermod -aG "$group" "$username"
    done

    # Set password and log it securely
    password=$(generate_password)
    echo "$username:$password" | chpasswd
    echo "$(date) - Created user $username with groups $groups" >> /var/log/user_management.log
    echo "$username:$password" >> /var/secure/user_passwords.txt

    # Set permissions and ownership for home directory
    chown -R "$username:$username" "/home/$username"
    chmod 700 "/home/$username"

done < "$input_file"


