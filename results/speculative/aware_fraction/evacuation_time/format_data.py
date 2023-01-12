import csv
import sys
import os

# Get the current working directory
cwd = os.getcwd()

# Get a list of all the files in the current directory
filenames = os.listdir(cwd)

  
for filename in filenames:
    if filename.endswith('.csv'):
        infile = open(filename, 'r')
        reader = csv.reader(infile)
        output_filename = os.path.splitext(filename)[0] + '.txt'
        outfile = open(output_filename, 'w')

        # Skip the first 17 lines
        for i in range(17):
            next(reader)

        # Initialize an empty list to store the data points
        data = []

        # Iterate over the remaining lines
        for row in reader:
            x = row[0]
            y = row[1]
            data.append(f'({x},{y})')

        # Write the data points to the output file, with no spaces
        outfile.write(''.join(data))
