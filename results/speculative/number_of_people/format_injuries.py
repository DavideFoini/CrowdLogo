import csv
import sys

# Get the input file name from the command line
input_file_name = sys.argv[1]

# Open the input CSV file and read the 26th line
with open(input_file_name, 'r') as input_file:
    reader = csv.reader(input_file)
    for i, row in enumerate(reader):
        if i == 10:
            people_row = row[1:]
        if i == 25:
            values = row[1:]
            break

# Initialize the output file counter
output_file_counter = 1
j=0
# Iterate over every 6 values and write them to a new output file
for i in range(0, len(values), 7):
    # Generate the output file name by appending the counter to the input file name
    output_file_name = input_file_name[0:-4] + str(output_file_counter) + '.txt'
    people_num = 30000 - (2500*j)
    j = j + 1
    # Open the output file
    with open(output_file_name, 'w') as output_file:
        # Write the values with the corresponding labels
        output_file.write('(HEALTHY,' + str(float(values[i])/people_num) + ')')
        output_file.write('(MINOR,' + str(float(values[i+1])/people_num) + ')')
        output_file.write('(MODERATE,' + str(float(values[i+2])/people_num) + ')')
        output_file.write('(SERIOUS,' + str(float(values[i+3])/people_num) + ')')
        output_file.write('(SEVERE,' + str(float(values[i+4])/people_num) + ')')
        output_file.write('(CRITICAL,' + str(float(values[i+5])/people_num) + ')')
        output_file.write('(FATAL,' + str(float(values[i+6])/people_num) + ')')

    # Increment the output file counter
    output_file_counter += 1
