#!/bin/bash

# Function to display the help message
usage() {
    echo "Usage: $0 [OPTIONS] TARGET"
    echo
    echo "Options:"
    echo "  -h, --help          Display this help message and exit"
    echo "  -p, --project NAME  Specify a project name for the scan"
    echo "  -raw                Perform a detailed scan and save raw data"
    echo
}

# Default value for md_editor_vault path  (DEFUALT: not set)
md_editor_vault=""

# Function to create the directory structure
create_directory() {
    if [ -n "$PROJECT_NAME" ]; then
        DIRECTORY="$PROJECT_NAME"
    else
        DIRECTORY="ReptorReport-$(date +'%Y-%m-%d_%H-%M')"
    fi
    IP_DIRECTORY="$DIRECTORY/$TARGET"
    mkdir -p "$IP_DIRECTORY"
    mkdir -p "$IP_DIRECTORY/RAWDATA"
}

# Check if at least one argument is provided
if [ "$#" -lt 1 ]; then
    usage
    exit 1
fi

PROJECT_NAME=""
RAW_FLAG=false

# Process the flags
while [[ "$1" =~ ^- ]]; do
    case $1 in
        -h | --help)
            usage
            exit 0
            ;;
        -p | --project)
            shift
            PROJECT_NAME="$1"
            ;;
        -raw)
            RAW_FLAG=true
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
    shift
done

# Store the target (IP address or domain)
TARGET=$1

# Check if a target is specified
if [ -z "$TARGET" ]; then
    echo "Error: No target specified"
    usage
    exit 1
fi

# Create the directory structure
create_directory

# Confirmation of script start
echo "Starting script for target: $TARGET"
echo "Saving results in: $IP_DIRECTORY"
echo

# Run Nmap to scan TCP ports and format the result
echo "Scanning TCP ports..."
TCP_PORTS=$(nmap -Pn -n "$TARGET" | grep open | cut -d/ -f1 | awk '{printf "%s, ", $1}' | sed 's/, $//')
echo "TCP scan completed."
echo

# Run Nmap to scan UDP ports and format the result
echo "Scanning UDP ports..."
UDP_PORTS=$(sudo nmap -Pn -n "$TARGET" --min-rate=1000 --max-retries=1 -sU | grep open | cut -d/ -f1 | awk '{printf "%s, ", $1}' | sed 's/, $//')
echo "UDP scan completed."
echo

# Save quick scan results in quickscan.md in Markdown format
echo "Creating quickscan.md..."
cat <<EOF > "$IP_DIRECTORY/quickscan.md"
# Quick Scan Results

| IP Address | Protocol | Open Ports |
|------------|----------|------------|
| $TARGET    | TCP      | $TCP_PORTS |
| $TARGET    | UDP      | $UDP_PORTS |

EOF
echo "quickscan.md saved."
echo
echo "Displaying content of quickscan.md:"
cat "$IP_DIRECTORY/quickscan.md"
echo

# Run Nmap for a full port scan and format the result
echo "Scanning all ports (TCP and UDP)..."
ALL_TCP_PORTS=$(nmap -Pn -n "$TARGET" -p- | grep open | cut -d/ -f1 | awk '{printf "%s, ", $1}' | sed 's/, $//')
ALL_UDP_PORTS=$(sudo nmap -Pn -n "$TARGET" --min-rate=1000 --max-retries=2 -p- -sU | grep open | cut -d/ -f1 | awk '{printf "%s, ", $1}' | sed 's/, $//')
echo "Full port scan completed."
echo

# Save full scan results in fullscan.md in Markdown format
echo "Creating fullscan.md..."
cat <<EOF > "$IP_DIRECTORY/fullscan.md"
# Full Scan Results

| IP Address | Protocol     | Open Ports           |
|------------|--------------|----------------------|
| $TARGET    | TCP (all)    | $ALL_TCP_PORTS       |
| $TARGET    | UDP (all)    | $ALL_UDP_PORTS       |

EOF
echo "fullscan.md saved."
echo

# Perform the RAW data scan only if the -raw flag is set
if [ "$RAW_FLAG" = true ]; then
    echo "Performing RAW data scan..."
    nmap -Pn -n -sV -sC -p"$ALL_TCP_PORTS" "$TARGET" -oA "${IP_DIRECTORY}/RAWDATA/${TARGET}_tcp_scan"
    echo "RAW data scan completed and saved to ${IP_DIRECTORY}/RAWDATA/${TARGET}_tcp_scan."
fi

# Check if TCP ports were found
if [ -n "$ALL_TCP_PORTS" ]; then
    # Create separate files for each found TCP port and perform a script scan for each port
    for port in $(echo $ALL_TCP_PORTS | tr ',' ' '); do
        if [ "$port" != "Not" ]; then
            echo "Creating file and performing script scan for TCP port $port..."
            cat <<EOF > "$IP_DIRECTORY/tcp-$port.md"
## Enumeration

# TCP Port $port Scan Result

EOF
            # Nmap script scan for this specific port and save the output in the file
            nmap_output=$(nmap -Pn -n -sV -sC -p"$port" "$TARGET")
            echo '```' >> "$IP_DIRECTORY/tcp-$port.md"
            echo "$nmap_output" >> "$IP_DIRECTORY/tcp-$port.md"
            echo '```' >> "$IP_DIRECTORY/tcp-$port.md"
        fi
    done
fi

# Check if UDP ports were found
if [ -n "$ALL_UDP_PORTS" ]; then
    # Create separate files for each found UDP port and perform a script scan for each port
    for port in $(echo $ALL_UDP_PORTS | tr ',' ' '); do
        if [ "$port" != "Not" ]; then
            echo "Creating file and performing script scan for UDP port $port..."
            cat <<EOF > "$IP_DIRECTORY/udp-$port.md"
## Enumeration

# UDP Port $port Scan Result

EOF
            # Nmap script scan for this specific port and save the output in the file
            nmap_output=$(sudo nmap -Pn -n -sV -sC -p"$port" -sU "$TARGET")
            echo '```' >> "$IP_DIRECTORY/udp-$port.md"
            echo "$nmap_output" >> "$IP_DIRECTORY/udp-$port.md"
            echo '```' >> "$IP_DIRECTORY/udp-$port.md"
        fi
    done
fi

# Check if the Markdown editor vault path is set and copy the project folder to that path
if [ -n "$md_editor_vault" ]; then
    echo "Copying project folder to: $md_editor_vault"
    cp -r "$DIRECTORY" "$md_editor_vault"
    echo "Project folder successfully copied to $md_editor_vault."
fi
