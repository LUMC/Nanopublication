require 'agraph'
require 'rdf'
require 'rdf/turtle'
require 'optparse'
require 'rdf-agraph'

# Define some useful RDF vocabularies.
FOAF = RDF::FOAF  # Standard "friend of a friend" vocabulary.
DC = RDF::DC
RDFS = RDF::RDFS
XSD = RDF::XSD
RSO = RDF::Vocabulary.new('http://rdf.biosemantics.org/ontologies/referencesequence#')
HG = RDF::Vocabulary.new('http://rdf.biosemantics.org/data/genomes/humangenome#')
NCBI = RDF::Vocabulary.new('http://rdf.biosemantics.org/ontologies/ncbiassembly#')
SO = RDF::Vocabulary.new('http://purl.org/obo/owl/SO#')
FANTOM5 = RDF::Vocabulary.new('http://rdf.biosemantics.org/data/riken/fantom5/data#')
PROV = RDF::Vocabulary.new('http://www.w3.org/ns/prov#')
OBO = RDF::Vocabulary.new('http://purl.org/obo/owl/obo#')
PAV = RDF::Vocabulary.new('http://swan.mindinformatics.org/ontologies/1.2/pav/')
NP = RDF::Vocabulary.new('http://www.nanopub.org/nschema#')


AnnotationSignChars = '+-'

# $repo = RDF::AllegroGraph::Repository.new("http://agraph:agraph@localhost:10035/fantom5")

server = AllegroGraph::Server.new :host => 'implicitome.cloud.tilaa.nl', :port => 81, :username => "riken", :password => "r1k3n"
catalog = AllegroGraph::Catalog.new server, "riken"
$repo = RDF::AllegroGraph::Repository.new(:server => catalog, :id => "nanopub1")
$repo.clear

# server = AllegroGraph::Server.new :username => "agraph", :password => "agraph"
# catalog = AllegroGraph::Catalog.new server, "nanopubs"
# $repo = AllegroGraph::Repository.new catalog, "fantom5"
# $repo.statements.delete

def insertGraph(g, triples)
	g_uri = g.to_uri
	for s, p, o in triples do
		$repo.insert([s.to_uri, p, o, g_uri])
	end
end


def create_nanopub1(annotation, nanopub, index)

	# setup nanopub
	base = RDF::Vocabulary.new(nanopub['#'])
	insertGraph(base, [
		[nanopub, RDF.type, NP.Nanopublicaiton, base],
		[nanopub, NP.hasAssertion, base.assertion, base],
		[nanopub, NP.hasProvenance, base.provenance, base],
		[nanopub, NP.hasPublicationInfo, base.publicationInfo, base]
	])

	# assertion graph
	if annotation =~ /chr(\d+):(\d+)\.\.(\d+),([#{AnnotationSignChars}])/
		chromosome, start_pos, end_pos, sign = $1, $2, $3, $4
		location = FANTOM5["loc_#{annotation}"]
		orientation = sign == '+' ? RSO.forward : RSO.reverse
		insertGraph(base.assertion, [
			[FANTOM5[annotation], RDF.type, SO.SO_0001917],
			[FANTOM5[annotation], RSO.mapsTo, location],
			[location, RDF.type, RSO.SequenceLocation],
			[location, RSO.start, RDF::Literal.new(start_pos.to_i, :datatype => XSD:int],
			[location, RSO.end, end_pos.to_i],
			[location, RSO.hasOrientation, orientation]
		])
	else
		puts "Unknown annotation format: #{annotation}"
	end

	# provenance graph
	insertGraph(base.provenance, [
		[base.assertion, OBO.RO_0003001, RDF::URI.new('http://rdf.biosemantics.org/data/riken/fantom5/experiment')],
		[base.assertion, PROV.derivedFrom, RDF::URI.new("http://rdf.biosemantics.org/dataset/riken/fantom5/void/row_#{index}")]
	])

	# publication info graph
	insertGraph(base.publicationInfo, [
		[nanopub, PAV.authoredBy, RDF::URI.new('http://rdf.biosemantics.org/data/riken/fantom5/project')],
		[nanopub, PAV.createdBy, 'Andrew Gibson'],
		[nanopub, PAV.createdBy, 'Mark Thompson'],
		[nanopub, PAV.createdBy, 'Zuotian Tatum'],
		[nanopub, DC.rights, RDF::URI.new('http://creativecommons.org/licenses/by/3.0/')],
		[nanopub, DC.rightsHolder, RDF::URI.new('http://www.riken.jp/')],
		[nanopub, DC.created, RDF::Literal.new(Time.now.utc, :datatype => XSD.dateTime)]
	])

	puts "inserted nanopub <#{nanopub}>"
	# puts "Current store size: #{$repo.count}"
end

def convert(options)
	base_url = 'http://rdf.biosemantics.org/nanopubs/riken/fantom5/'

	index = 0
	line_number = 0
	File.open(options[:input], 'r') do |f|
		while line = f.gets

			# ignore comments and header row
			if line =~ /^chr/
				index += 1
				nanopub = RDF::Vocabulary.new("#{base_url}#{index}")
				annotation, shortDesc, description, transcriptAssociation, geneEntrez, geneHgnc, geneUniprot, *samples = line.split("\t")
				create_nanopub1(annotation, nanopub, index)
			else
				# puts "Unused input line: #{line_number}"
			end
			line_number += 1
		end
	end

end


options = {}
OptionParser.new do |opts|
 	opts.banner = "Usage: fantom5.rb -i data.txt"

	opts.on("-i", "--input ASSEMBLY") do |input|
		if input.nil?
			puts "input file is missing."
			exit 1
		end
		options[:input] = input
  	end

	opts.on("-o", "--output FILENAME") do |output|
		options[:output] = output
	end

	opts.on("--host HOSTNAME") do |host|
		options[:host] = host || "localhost"
	end

	opts.on("--port NUMBER") do |port|
		optiosn[:port] = port || 10035
	end

	opts.on("--catalog CATALOGNAME") do |catalog|
		options[:catalog] = catalog
	end

	opts.on("--repository REPOSITORYNAME") do |repository|
		options[:repository] = repository
	end

	# No argument, shows at tail.  This will print an options summary.
	opts.on_tail("-h", "--help", "Show this message") do
		puts opts
		exit
	 end
end.parse!

# call main
convert(options)

