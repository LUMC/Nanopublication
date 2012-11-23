require 'agraph'
require 'rdf'
require 'rdf/turtle'
require 'optparse'
require 'rdf-agraph'
require_relative 'converter'

# Define some useful RDF vocabularies.
FOAF = RDF::FOAF 
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


module Nanopublication
	class Fantom5_Nanopub_Converter < RDF_Converter

		@@AnnotationSignChars = '+-'

		def initialize(options)
			default = {
				:server => 'localhost',
				:port => 10035,
				:base_url => 'http://rdf.biosemantics.org/nanopubs/riken/fantom5/'
			}

			options = default.merge(options)
			super

			@server = AllegroGraph::Server.new(:host=>options[:host], :port=>options[:port], 
											   :username=>"agraph", :password=>"agraph")
			@catalog = options[:catalog].nil? ? @server : AllegroGraph::Catalog.new(@server, options[:catalog])
			@repository = RDF::AllegroGraph::Repository.new(:server=>@catalog, :id=>options[:repository])
			@repository.clear
		end

		def convert_header_row(row)
			# do nothing
		end

		def convert_row(row)
			# ignore summary rows
			if row =~ /^chr/
				@row_index += 1
				annotation, shortDesc, description, transcriptAssociation, geneEntrez, geneHgnc, geneUniprot, *samples = row.split("\t")
				create_class1_nanopub(annotation)
				create_class2_nanopub(annotation, transcriptAssociation)
				exit
			end
		end

		protected
		def insertGraph(g, triples)
			g_uri = g.to_uri
			for s, p, o in triples do
				@repository.insert([s.to_uri, p, o, g_uri])
			end
		end

		protected
		def create_class1_nanopub(annotation)
			if annotation =~ /chr(\d+):(\d+)\.\.(\d+),([#{@@AnnotationSignChars}])/
				chromosome, start_pos, end_pos, sign = $1, $2, $3, $4

				# setup nanopub
				nanopub = RDF::Vocabulary.new(@base['cage_clusters/' + @row_index.to_s])
				assertion = nanopub['#assertion']
				provenance = nanopub['#provenance']
				publicationInfo = nanopub['#publicationInfo']

				insertGraph(nanopub, [
					[nanopub, RDF.type, NP.Nanopublicaiton],
					[nanopub, NP.hasAssertion, assertion],
					[nanopub, NP.hasProvenance, provenance],
					[nanopub, NP.hasPublicationInfo, publicationInfo]
				])

				# assertion graph
				location = FANTOM5["loc_#{annotation}"]
				orientation = sign == '+' ? RSO.forward : RSO.reverse
				insertGraph(assertion, [
					[FANTOM5[annotation], RDF.type, SO.SO_0001917],
					[FANTOM5[annotation], RSO.mapsTo, location],
					[location, RDF.type, RSO.SequenceLocation],
					[location, RSO.start, RDF::Literal.new(start_pos.to_i, :datatype => XSD.int)],
					[location, RSO.end, RDF::Literal.new(end_pos.to_i, :datatype =>XSD.int)],
					[location, RSO.hasOrientation, orientation]
				])

				# provenance graph
				insertGraph(provenance, [
					[assertion, OBO.RO_0003001, RDF::URI.new('http://rdf.biosemantics.org/data/riken/fantom5/experiment')],
					[assertion, PROV.derivedFrom, RDF::URI.new("http://rdf.biosemantics.org/dataset/riken/fantom5/void/row_#{@row_index}")]
				])

				# publication info graph
				insertGraph(publicationInfo, [
					[nanopub, PAV.authoredBy, RDF::URI.new('http://rdf.biosemantics.org/data/riken/fantom5/project')],
					[nanopub, PAV.createdBy, 'Andrew Gibson'],
					[nanopub, PAV.createdBy, 'Mark Thompson'],
					[nanopub, PAV.createdBy, 'Zuotian Tatum'],
					[nanopub, DC.rights, RDF::URI.new('http://creativecommons.org/licenses/by/3.0/')],
					[nanopub, DC.rightsHolder, RDF::URI.new('http://www.riken.jp/')],
					[nanopub, DC.created, RDF::Literal.new(Time.now.utc, :datatype => XSD.dateTime)]
				])

				puts "inserted nanopub <#{nanopub}>"
			else
				puts "Unknown annotation format: #{annotation}"
			end
		end

		protected 
		def create_class2_nanopub(annotation, transcriptAssociation)
			# TODO
		end

	end
end

options = {}
OptionParser.new do |opts|
 	opts.banner = "Usage: fantom5.rb -i data.txt"

	opts.on("-i", "--input ASSEMBLY") do |input|
		options[:input] = input
  	end

	opts.on("-o", "--output FILENAME") do |output|
		options[:output] = output
	end

	opts.on("--host HOSTNAME", 'default to localhost') do |host|
		options[:host] = host 
	end

	opts.on("--port NUMBER", 'default to 10035') do |port|
		optiosn[:port] = port.to_i
	end

	opts.on("--catalog CATALOGNAME") do |catalog|
		options[:catalog] = catalog
	end

	opts.on("--repository REPOSITORYNAME") do |repository|
		options[:repository] = repository
	end

	opts.on("--base BASEURL") do |base_url|
		options[:base_url] = base_url
	end

	# No argument, shows at tail.  This will print an options summary.
	opts.on_tail("-h", "--help", "Show this message") do
		puts opts
		exit
	end
end.parse!

# check for required arguments
if options[:input].nil?
	puts "input file is missing."
	exit 1
end

# do the work
converter = Nanopublication::Fantom5_Nanopub_Converter.new(options)
converter.convert
