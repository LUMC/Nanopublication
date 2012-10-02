# take a genome assembly report and convert it to triples.
# you can find assembly reports at ftp://ftp.ncbi.nlm.nih.gov/genomes/ASSEMBLY_REPORTS/

require 'rdf'
require 'rdf/turtle'
require 'optparse'

# namespaces
DC = RDF::DC
RDFS = RDF::RDFS
XSD = RDF::XSD
RS = RDF::Vocabulary.new('http://rdf.biosemantics.org/ontologies/ReferenceSequence#')
$base = RDF::Vocabulary.new('http://rdf.biosemantics.org/data/genome/assembly/hg19#')

prefixes = {
    :dcterms => DC,
    :rdf => RDF,
    :xsd => XSD,
    :rdfs => RDFS,
    :rs => RS,
    nil => $base
}

graph = RDF::Graph.new($base)

# @param [Object] row
def convert(graph, row)
  name, role, cp, genebank_accn, refseq_accn, unit = row.strip.split("\t")
  if unit == 'Primary Assembly'
    graph << [$base[name], RDF.type, RS.ReferenceSequence]
  elsif unit == 'non-nuclear'

  end
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: assembly_report_converter.rb -i xxx.assembly.txt -o xxx.assembly.ttl"

  # Mandatory argument.
  opts.on("-i", "--input ASSEMBLY") do |input|
    options[:input] = input
  end

  opts.on("-o", "--output FILENAME") do |output|
    options[:output] = output
  end

  # No argument, shows at tail.  This will print an options summary.
  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end.parse!

File.open(options[:input], 'r') do |f|
  while line = f.gets
    if line[0] != '#'
        convert(graph, line)
    end
  end
end

RDF::Turtle::Writer.open('assembly.test.ttl') do |writer|
  writer.prefixes = prefixes
  writer.base_uri = $base
  writer << graph
end