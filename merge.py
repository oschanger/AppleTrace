#!/usr/bin/env python
#
# created by everettjf 20170915
#
# Input  : Path of directory , which include raw *.ostrace files.
# Output : Path of output json file , which will be given to catapult.
#

import os
import json
from optparse import OptionParser

class Merger:
    def __init__(self,dir):
        self.dir = dir
        self.output_path = os.path.join(dir,"trace.json")

        if os.path.exists(self.output_path):
            os.remove(self.output_path)

        self.output = open(self.output_path,'w')
        self.output.write('[\n')
        self.jsons=[]

    def append(self,line):
        line = line.strip('\n')
        #print len(line),' : ', line
        self.output.write(line)
        self.output.write(',\n')

    def merge_file(self,file_path):
        file = open(file_path)
        while True:
            line = file.readline()
            if not line or len(line) == 0:
                break
            if line[0] != '{':
                break
            self.append(line)

    def merge_file_json(self,file_path):
        file = open(file_path)
        while True:
            line = file.readline()
            if not line or len(line) == 0:
                break
            if line[0] != '{':
                break
            line = line.strip('\n')
            self.jsons.append(json.loads(line,strict=False))
    
    def write_json_to_result(self):
        for j in self.jsons:
            self.output.write(json.dumps(j))
            self.output.write(',\n')

    def run(self):
        for root,dirs,files in os.walk(self.dir):
            for file in files:
                if file.endswith("appletrace"):
                    filepath = os.path.join(root,file)
                    self.merge_file_json(filepath)
        self.jsons.sort(key = lambda x:x["ts"])
        self.write_json_to_result()
        print("trace.json generate complete")

    def run_old(self):
        i = 0
        while True:
            if i == 0:
                file_path = os.path.join(self.dir,"trace.appletrace")
            else:
                file_path = os.path.join(self.dir,"trace_%d.appletrace" % (i))

            if not os.path.exists(file_path):
                break

            self.merge_file(file_path)
            i+=1

def main():
    p = OptionParser('usage: %prog -d <directory_path>')
    p.add_option("-d","--dir",dest="dir",help="directory path that include all ostrace files")

    (options,args) = p.parse_args()
    if options.dir is None:
        p.print_help();
        return

    if options.dir:
        # merge into json
        m = Merger(options.dir)
        m.run()

if __name__ == '__main__':
    main()
