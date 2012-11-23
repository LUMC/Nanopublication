# take a NCBI genome assembly report and convert it to triples.
# triples include a URI of the genome assembly, and URIs of all reference sequences that 
# are part of this genome build.
# you can find assembly reports at ftp://ftp.ncbi.nlm.nih.gov/genomes/ASSEMBLY_REPORTS/

require 'rdf'
require 'rdf/turtle'
require 'optparse'


# namespaces
DC = RDF::DC
RDFS = RDF::RDFS
XSD = RDF::XSD
RS = RDF::Vocabulary.new('http://rdf.biosemantics.org/ontologies/referencesequence#')
HG = RDF::Vocabulary.new('http://rdf.biosemantics.org/data/genomes/humangenome#')
NCBI = RDF::Vocabulary.new('http://rdf.biosemantics.org/ontologies/ncbiassembly#')
TMP = RDF::Vocabulary.new('http://tmp#')
$prefixes = {
    :dcterms => DC,
    :rdf => RDF,
    :xsd => XSD,
    :rdfs => RDFS,
    :rs => RS,
    :ncbi => NCBI,
    :hg =>HG
}

# @param [Object] row
def convert_reference_sequence(graph, row, base)
    name, role, cp, genbank_accn, refseq_accn, unit = row.split("\t")
    graph << [base[name], RDF.type, RS.ReferenceSequence]
    graph << [base[name], DC.partOf, base['Assembly']]
    graph << [base[name], NCBI.hasRole, NCBI[role.downcase.gsub(/[\s\-]/, '_')]]
    graph << [base[name], NCBI.inAssemblyUnit, NCBI[unit.downcase.gsub(/[\s\-]/, '_')]]

    if not cp.empty?
        if role == 'chromosome'
            graph << [base[name], RS.represents, HG['chr' + cp]]
        else 
            graph << [base[name], RS.isAssociatedWith, HG['chr' + cp]]
        end
    end

    if not genbank_accn.empty?
        graph << [base[name], RS.genBankID, genbank_accn]
    end

    if not refseq_accn.empty?
        graph << [base[name], RS.refSeqID, refseq_accn]
    end
end

def annotate_assembly(graph, row, base)

  annotation_mapping = {
      'Assembly Name' => DC.title,
      'Description' => RDFS.label,
      'Submitter' => DC.creator,
      'Release type' => NCBI.releaseType,
      'Genome representation' => NCBI.genomeRepresentation
  }

  assembly = base['Assembly']

  if row =~ /\#\ ([^\:]+)\:\s*(.+)/
    description, value = $1, $2
    if annotation_mapping.has_key?(description)
        graph << [assembly, annotation_mapping[description], value]
    elsif description == 'Assembly level'
        graph << [assembly, NCBI.level, NCBI[value.downcase + '_level']]
    elsif description == 'GenBank Assembly ID'
        if value =~ /([^\s]+)\s*\(([\w]+)\)/
            id, status = $1, $2
            graph << [assembly, RS.genBankAssemblyID, id]
        else
            graph << [assembly, RS.genBankAssemblyID, value]
        end
    elsif description == 'Assembly type'
        case value
        when 'haploid-with-alt-loci'
            graph << [assembly, RDF.type, NCBI.HaploidAltAssembly]
        else
            graph << [assembly, RDF.type, RS.GenomeAssemlby]
        end
    elsif description == 'Taxid'
        graph << [assembly, NCBI.taxID, RDF::URI.new('http://purl.obolibrary.org/obo/NCBITaxon_' + value)]
    else
        puts 'ignore annotation "' + description + '"'
    end
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
