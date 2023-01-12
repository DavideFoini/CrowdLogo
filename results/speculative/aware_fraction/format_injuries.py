import csv
import sys

# Get the input file name from the command line
input_file_name = sys.argv[1]

# Open the input CSV file and read the 26th line
with open(input_file_name, 'r') as input_file:
    reader = csv.reader(input_file)
    for i, row in enumerate(reader):
        if i == 25:
            values = row[1:]
            break

# Initialize the output file counter
output_file_counter = 1

# Iterate over every 6 values and write them to a new output file
for i in range(0, len(values), 7):
    # Generate the output file name by appending the counter to the input file name
    output_file_name = input_file_name[0:-4] + str(output_file_counter) + '.txt'

    # Open the output file
    with open(output_file_name, 'w') as output_file:
        # Write the values with the corresponding labels
        output_file.write('(HEALTHY,' + values[i] + ')')
        output_file.write('(MINOR,' + values[i+1] + ')')
        output_file.write('(MODERATE,' + values[i+2] + ')')
        output_file.write('(SERIOUS,' + values[i+3] + ')')
        output_file.write('(SEVERE,' + values[i+4] + ')')
        output_file.write('(CRITICAL,' + values[i+5] + ')')
        output_file.write('(FATAL,' + values[i+6] + ')')

    # Increment the output file counter
    output_file_counter += 1
