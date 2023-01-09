import csv
import sys
import os

# Get the input file name from the command-line arguments
input_filename = sys.argv[1]

# Create the output file name by replacing the file extension of the input file
output_filename = os.path.splitext(input_filename)[0] + '.txt'

# Open the input and output files
with open(input_filename, 'r') as infile, open(output_filename, 'w') as outfile:
  # Create a CSV reader
  reader = csv.reader(infile)
  
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
  outfile.write(''.join
