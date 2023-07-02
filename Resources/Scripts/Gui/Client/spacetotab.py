#me absolute dumbass used to use spaces instead of tabs

import os
import sys

import argparse
parser  = argparse.ArgumentParser(description="replace spaces with tabs")
parser.add_argument('file', default='spacetotab.py', help="File to read from")
parser.add_argument('spaces', default=4, type=int, help="how many spaces to turn into a tab")
args = parser.parse_args()

is_file = os.path.dirname(__file__) + "/" + args.file
if not os.path.exists(is_file):
	print("no file by that name found in current directory. typo?")
	sys.exit()

is_space = 0
dont_tabulate = ["\n", "\t", "\v", "\r", "\f"]
with open(args.file, "r") as fo:
	with open(args.file + ".corrected", "w") as fn:
		while True:
			letter = fo.read(1)
			if not letter:
				print("done. ^w^")
				break
			if letter.isspace() and letter not in dont_tabulate:
				is_space += 1
				if is_space == args.spaces:
					fn.write("\t")
					is_space = 0
				continue
			if is_space > 0:
				i = 0
				while i < is_space:
					fn.write(" ")
					i += 1
				is_space = 0
			fn.write(letter)
			
		fn.close()	
	fo.close()
		
