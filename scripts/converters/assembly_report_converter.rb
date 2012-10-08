# take a genome assembly report and convert it to triples.
# triples include a URI to the genome assembly, and URIs to all reference sequences that are part of this
# genome build.
# you can find assembly reports at ftp://ftp.ncbi.nlm.nih.gov/genomes/ASSEMBLY_REPORTS/

require 'rdf'
require 'rdf/turtle'
require 'optparse'
require 'titlecase'


# namespaces
DC = RDF::DC
RDFS = RDF::RDFS
XSD = RDF::XSD
RS = RDF::Vocabulary.new('http://rdf.biosemantics.org/ontologies/ReferenceSequence#')
GB = RDF::Vocabulary.new('http://rdf.biosemantics.org/ontologies/GeneBank#')
HG = RDF::Vocabulary.new('http://rdf.biosemantics.org/data/genomes/humangenome#')

$prefixes = {
    :dcterms => DC,
    :rdf => RDF,
    :xsd => XSD,
    :rdfs => RDFS,
    :rs => RS,
    :gb => GB,
    :hg =>HG
}

# say something about the genome assembly.

# @param [Object] row
def convert_reference_sequence(graph, row, base)
  name, role, cp, genebank_accn, refseq_accn, unit = row.split("\t")
  if unit == 'Primary Assembly' or unit == 'non-nuclear'
    graph << [base[name], RDF.type, RS.ReferenceSequence]
    graph << [base[name], DC.partOf, base['Assembly']]
    graph << [base[name], RS.role, role]
    graph << [base[name], RS.assemblyUnit, unit]
    if not cp.empty?
      graph << [base[name], RS.locatesIn, HG['chr' + cp]]
    end
    graph << [base[name], RDFS.seeAlso, RDF::URI.new('http://www.ncbi.nlm.nih.gov/nuccore/' + genebank_accn)]
    graph << [base[name], RDFS.seeAlso, RDF::URI.new('http://www.ncbi.nlm.nih.gov/nuccore/' + refseq_accn)]
  end
end

def annotate_assembly(graph, row, base)
  if row =~ /\#\ ([^\:]+)\:\s*(.+)/
    description, value = $1, $2
    graph << [base['Assembly'], GB[description.titlecase.gsub(/\s/, '')], value]
  else
    puts 'row not conforming to format, ignore'
  end
end


def convert(options)
  base = RDF::Vocabulary.new('http://rdf.biosemantics.org/data/genomeassemblies/' + options[:name] + '#')

  graph = RDF::Graph.new(base)
  $prefixes[nil] = base

  # some meta data on the file.
  graph << [base[''], RDF.type, DC.document]
  graph << [base[''], DC.creator, 'Zuotian Tatum']
  graph << [base[''], DC.created, Time.now.utc.iso8601]

  graph << [base['Assembly'], RDF.type, RS.GenomeAssembly]

  File.open(options[:input], 'r') do |f|
    while line = f.gets
      if line[0] == '#'
        annotate_assembly(graph, line.strip, base)
      else
        convert_reference_sequence(graph, line.strip, base)
      end
    end
  end

  RDF::Turtle::Writer.open('assembly.test.ttl') do |writer|
    writer.prefixes = $prefixes
    writer.base_uri = base
    writer << graph
  end
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: assembly_report_converter.rb -n hg19 -i xxx.assembly.txt -o xxx.assembly.ttl"

  # Mandatory argument.
  opts.on("-n", "--name NAME") do |name|
    options[:name] = name
  end

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

# call main
convert(options)
