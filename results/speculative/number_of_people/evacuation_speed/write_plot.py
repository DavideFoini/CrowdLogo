import sys

# Check if we have the correct number of command line arguments
if len(sys.argv) != 4:
    print("Error: program requires three command line arguments")
    sys.exit(1)

# Open the first file for reading, the second file for reading, and the third file for writing
with open(sys.argv[1], 'r') as infile, open(sys.argv[2], 'r') as insertfile, open(sys.argv[3], 'w') as outfile:
    # Read the first line of the second file
    insert_line = insertfile.readline()
    
    # Read the first file line by line
    for line in infile:
        # Check if the line contains the string '{}'
        if '{}' in line:
            # Replace the '{}' with the current line of the second file
            line = line.replace('{}', '{' + insert_line + '}')
            # Read the next line of the second file
            insert_line = insertfile.readline()
        # Write the modified line to the output file
        outfile.write(line)
