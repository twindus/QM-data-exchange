#!/usr/bin/python
from __future__ import with_statement
import os
import io
from itertools import tee, izip
from multiprocessing import Process
#
# Gather initial values from user
#
steps = int(raw_input('Total time per simulation (in fs): '))
stepsize =  float(raw_input('Time-step size (in fs): '))
equil = int(raw_input('Equilibration time (in fs): '))
#strength = float(raw_input('SFORCE value: '))
#increment = float(raw_input('Step size for umbrella sampling: '))
float(steps)
float(equil)
steps = int(steps / stepsize)
equil = int(equil / stepsize)
print steps 
print equil
#
# Get list of log files to process
#
files = [f for f in os.listdir('.') if os.path.isfile(f)]
#
# Initialize file names
#
radline = ''
potline = ''
numfile = 'seq'

with open(numfile + '.out', 'w') as numF:
    for x in range(1,(steps - equil) + 1):
        linenum = str(x) + '\n'
        numF.write(linenum)

def find_radius(inF):
    radfile = open(inF + '.rad', 'w')
    with open(inF, 'r') as f:
        for line in f:
            if 'Radius' in line:
                radline = line[30:48]
                radfile.write(radline)

def find_poten(inF):
    potfile = open(inF + '.pot', 'w')
    with open(inF, 'r') as f:
        for line in f:
            if 'POT  ENERGY' in line:
                potline =  line[25:45] + "\n"
                potfile.write(potline)
                
def pairwise(iterable):
    files, nfiles = tee(iterable)
    next(nfiles, None)
    return izip(files, nfiles)

for f1, f2 in pairwise(files):
#
# Launch two processes per file, one for each search (radius and potential energy)
#
    p1 = Process(target=find_radius, args=(f1,))
    p2 = Process(target=find_poten, args=(f1,))
    p3 = Process(target=find_radius, args=(f2,))
    p4 = Process(target=find_poten, args=(f2,))
    p1.start()
    p2.start()
    p3.start()
    p4.start()
    p1.join()
    p2.join()
    p3.join()
    p4.join()
#
# Set up file name variables
#
    left1= f1 + '.rad'
    right1= f1 + '.pot'
    output1 = f1 + '.tmp'
    finout1 = f1 + '.wham'
    left2= f2 + '.rad'
    right2= f2 + '.pot'
    output2 = f2 + '.tmp'
    finout2 = f2 + '.wham'
#
# Put radius and potential energy files together
#
    cmd1 = "paste %s %s > %s" % (left1, right1, output1)
    cmd2 = "paste %s %s > %s" % (left2, right2, output2)
    os.system(cmd1)
    os.system(cmd2)
#
# Add line numbers 
#
    chop1 = "sed -i 1,%sd %s" % (equil + 1, output1)
    chop2 = "sed -i 1,%sd %s" % (equil + 1, output2)
    final1 = "paste %s %s > %s" % (numfile + '.out', output1, finout1)
    final2 = "paste %s %s > %s" % (numfile + '.out', output2, finout2)
    os.system(chop1)
    os.system(chop2)
    os.system(final1)
    os.system(final2)
#
# Clean up unnecessary files
#
#    clean1 = "rm %s %s %s %s" % (left1, right1, output1, numfile + '.out')
#    clean2 = "rm %s %s %s" % (left2, right2, output2)
#    os.system(clean1)
#    os.system(clean2)

