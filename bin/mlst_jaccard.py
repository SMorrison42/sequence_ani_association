#!/usr/bin/env python3

import argparse
import Bio
from Bio import SeqIO
import os.path

def extract_headers(fasta_file):
    headers = {}
    with open(fasta_file, "r") as file:
        for record in Bio.SeqIO.FastaIO.SimpleFastaParser(file):
            # Split the header by space and add the second field to the dictionary as a key-value
            header_parts = record[0].split()
            #removeparse is not working with the version 3.8 and lower so adding a work around for now with SC batch analysis. Anu, 09/06/2024
            # if len(header_parts) > 1:
            #     headers[header_parts[0]] = header_parts[1].removeprefix('value_md5=') 
            if header_parts[1].startswith('value_md5='):
                headers[header_parts[0]] = header_parts[1][len('value_md5='):] ### added work around

    return headers

def compute_union_intersection_jaccard(set1, set2):
    union = set1.union(set2)
    intersection = set1.intersection(set2)
    jaccard_similarity = len(intersection) / len(union) if len(union) > 0 else 0
    return union, intersection, jaccard_similarity

def main(args):
    genome1 = extract_headers(args.fasta1)
    genome2 = extract_headers(args.fasta2)

    # Gene content differences
    union, intersection, jaccard_similarity = compute_union_intersection_jaccard(set(genome1.keys()), set(genome2.keys()))
    gene_difference  = union - intersection
    jaccard_distance = 1 - jaccard_similarity if args.distance else jaccard_similarity

    # Allele differences (only from genes present in intersection)
    allele_difference = set()
    for gene in intersection:
        if genome1[gene] == genome2[gene]:
            allele_difference.add(gene)
    allele_jaccard_similarity = len(allele_difference) / len(intersection) if len(intersection) > 0 else 0
    allele_jaccard_distance = 1 - allele_jaccard_similarity if args.distance else allele_jaccard_similarity
    
    print(f"{os.path.basename(args.fasta1)}\t{os.path.basename(args.fasta2)}\t{len(union)}\t{len(intersection)}\t{len(gene_difference)}\t{jaccard_distance:.4f}\t{len(allele_difference)}\t{allele_jaccard_distance:.4f}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Compute union, intersection, and Jaccard index of headers from two FASTA files")
    parser.add_argument("-f1", "--fasta1", help="First input FASTA file")
    parser.add_argument("-f2", "--fasta2", help="Second input FASTA file")
    parser.add_argument("-d", "--distance", action="store_true", help="(Optional) Convert Jaccard similarity to Jaccard distance")
    
    args = parser.parse_args()
    main(args)
