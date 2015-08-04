#!/usr/local/bin/python
############################################################################
# ncbiBlastServer.py - Server connecting directly to NCBI.
#    --es 10/10/2006
############################################################################
"""
NCBI BLAST server via BioPython client.

Usage: ncbiBlastServer.cgi
   Inputs cgi parameters:
      gene_oid - Gene object identifier
      seq - protein sequence for gene_oid
      db - "nr" for default
   Optional input parameters:
      top_n = <n> Number of top hits

   Output tab delimited fields:
      qid - query ID
      sid - subject ID
      percIdent - Percent identity
      alen - alignment length
      nMismatch - blank (not used)
      nGaps - blank (not used)
      qstart - query start
      qend - query end
      sstart - subject start
      send - subject end
      evalue - evalue
      bitScore - bit score

"""
import os, sys
import re
import cStringIO
import cgi
import urllib
from Bio import Fasta
from Bio.Blast import NCBIWWW

max_expect = "1e-2"
tool = "ncbiBlastServer"

############################################################################
# getVal
############################################################################
def getVal( line_count, s ):
   """ Get value from parsing XML tag line. """
   toks = re.split( "[<>]", s )
   count = 0
   #for t in toks:
   #   print "%d: '%s'" %( count, t )
   #   count += 1
   if len( toks ) > 3:
      return toks[ 2 ]
   sys.stderr.write( "ncbiBlastServer.cgi: Bad line %d '%s'\n" \
      %( line_count, s )  )
   return ""

############################################################################
# firstTok
############################################################################
def firstTok( s ):
   """ Get first token from whitespace seprated word line. """
   toks = re.split( "[\s+]", s )
   if len( toks ) == 0:
      return ""
   return toks[ 0 ]

############################################################################
# runBlast
############################################################################
def runBlast( gene_oid, seq, db, top_n ):
    """ Run NCBI BLAST from client and print to standard output. """

    fasta = ">%s\n" %( gene_oid )
    fasta += "%s\n" %( seq )
    fin = cStringIO.StringIO( fasta )
    fin_it = Fasta.Iterator( fin )
    f_record = fin_it.next( )

    res_handle = NCBIWWW.qblast( "blastp", db, f_record, \
       expect = max_expect )
    blast_results = res_handle.read( )
    string_results_handle = cStringIO.StringIO( blast_results )
    rec = { }
    line_count = 0;
    rec_count = 0
    for s in string_results_handle:
	line_count += 1
        if re.match( "^\s+<Iteration_query-def>", s ):
            rec[ 'qid' ] = firstTok( getVal( line_count, s ) )
        elif re.match( "^\s+<Hit_id>", s ):
            rec[ 'sid' ] = getVal( line_count, s )
        elif re.match( "^\s+<Hsp_bit-score>", s ):
            rec[ 'bit_score' ] = getVal( line_count, s )
        elif re.match( "^\s+<Hsp_evalue>", s ):
            rec[ 'evalue' ] = getVal( line_count, s )
        elif re.match( "^\s+<Hsp_query-from>", s ):
            rec[ 'qstart' ] = getVal( line_count, s )
        elif re.match( "^\s+<Hsp_query-to>", s ):
            rec[ 'qend' ] = getVal( line_count, s )
        elif re.match( "^\s+<Hsp_hit-from>", s ):
            rec[ 'sstart' ] = getVal( line_count, s )
        elif re.match( "^\s+<Hsp_hit-to>", s ):
            rec[ 'send' ] = getVal( line_count, s )
        elif re.match( "^\s+<Hsp_identity>", s ):
            rec[ 'identity' ] = getVal( line_count, s )
        elif re.match( "^\s+<Hsp_gaps>", s ):
            rec[ 'gaps' ] = getVal( line_count, s )
        elif re.match( "^\s+<Hsp_align-len>", s ):
            rec[ 'alen' ] = getVal( line_count, s )
        elif re.match( "^\s+</Hsp>", s ):
	    rec_count += 1
	    if rec_count > top_n:
	       break
            qid = rec[ 'qid' ]
            sid = rec[ 'sid' ]
            bitScore = "%.2f" %( float( rec[ 'bit_score' ] ) )
            evalue =  "%.0e" %( float( rec[ 'evalue' ] ) )
            alen = rec[ 'alen' ]
            identity = rec[ 'identity' ]
            qstart = rec[ 'qstart' ]
            qend = rec[ 'qend' ]
            sstart = rec[ 'sstart' ]
            send = rec[ 'send' ]
            percIdent = "%.2f" % ( float( identity ) * 100 / float( alen ) )
	    nMisMatch = ""
	    nGaps = ""
	    sys.stdout.write( "%s\t" %( qid ) )
	    sys.stdout.write( "%s\t" %( sid ) )
	    sys.stdout.write( "%s\t" %( percIdent ) )
	    sys.stdout.write( "%s\t" %( alen ) )
	    sys.stdout.write( "%s\t" %( nMisMatch ) )
	    sys.stdout.write( "%s\t" %( nGaps ) )
	    sys.stdout.write( "%s\t" %( qstart ) )
	    sys.stdout.write( "%s\t" %( qend ) )
	    sys.stdout.write( "%s\t" %( sstart ) )
	    sys.stdout.write( "%s\t" %( send ) )
	    sys.stdout.write( "%s\t" %( evalue ) )
	    sys.stdout.write( "%s\n" %( bitScore ) )
   

############################################################################
# main
############################################################################
def main( ):
    """ Main plain text CGI driver. """
    print "Content-type: text/html\n"

    fields = cgi.FieldStorage( )
    gene_oid = fields.getvalue( "gene_oid", "" )
    seq = fields.getvalue( "seq", "" )
    db = fields.getvalue( "db", "nr" )
    top_n = int( fields.getvalue( "top_n", "250" ) )
    if gene_oid == "":
       sys.stdout.write( "ERROR: gene_oid undefined\n" )
    if seq == "":
       sys.stdout.write( "ERROR: seq undefined\n" )

    ## testing
    test_debug = False
    if test_debug:
        gene_oid = "123_456_78"
        seq = "MLWTDCLTRLRQELSDNVFAMWIRPLVAEETTDSLRLYAPNPYWTRYIQE"
        seq += "HHLELISILVEQLSEGRIRQVEILVDSRPGAILSPAEQPATTTAALSSTP"
        seq += "VVPQRVKKEVVEPAATQSNKILNSKKRLLNPLFTFSLFVEGRSNQMAAET"
        db = "nr"
        top_n = 250

    runBlast( gene_oid, seq, db, top_n )


if __name__ == "__main__":
    main( )

