import os

# Get the current working directory
cwd = os.getcwd()

# Get a list of all the files in the current directory
filenames = os.listdir(cwd)

# Open the output file for writing
with open('combined.txt', 'w') as outfile:
    # Iterate through the list of filenames
    for filename in filenames:
        # Check if the file is a .txt file
        if filename.endswith('.txt'):
            # Open the file for reading
            with open(filename, 'r') as infile:
                # Write the contents of the file to the output file
                outfile.write(infile.read() + '\n')
