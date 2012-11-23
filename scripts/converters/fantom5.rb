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
HG19 = RDF::Vocabulary.new('http://rdf.biosemantics.org/data/genomeassemblies/hg19#')
SO = RDF::Vocabulary.new('http://purl.org/obo/owl/SO#')
FANTOM5 = RDF::Vocabulary.new('http://rdf.biosemantics.org/data/riken/fantom5/data#')
PROV = RDF::Vocabulary.new('http://www.w3.org/ns/prov#')
OBO = RDF::Vocabulary.new('http://purl.org/obo/owl/obo#')
PAV = RDF::Vocabulary.new('http://swan.mindinformatics.org/ontologies/1.2/pav/')
NP = RDF::Vocabulary.new('http://www.nanopub.org/nschema#')


class Fantom5_Nanopub_Converter < RDF_Converter

	@@AnnotationSignChars = '+-'

	def initialize(options)
		default = {
			:server => 'localhost',
			:port => 10035,
			:base_url => 'http://rdf.biosemantics.org/nanopubs/riken/fantom5/',
			:username => 'agraph',
			:password => 'agraph',
			:subtype => :cage_clusters
		}

		options = default.merge(options)
		super

		@server = AllegroGraph::Server.new(:host=>options[:host], :port=>options[:port], 
										   :username=>options[:username], :password=>options[:password])
		@catalog = options[:catalog].nil? ? @server : AllegroGraph::Catalog.new(@server, options[:catalog])
		@repository = RDF::AllegroGraph::Repository.new(:server=>@catalog, :id=>options[:repository])
		@repository.clear

		@subtype = options[:subtype]
	end

	def convert_header_row(row)
		# do nothing
	end

	def convert_row(row)
		# ignore summary rows
		if row =~ /^chr/
			@row_index += 1
			annotation, shortDesc, description, transcriptAssociation, geneEntrez, geneHgnc, geneUniprot, *samples = row.split("\t")
			#puts "#{annotation}, #{shortDesc}, #{description}"
			case @subtype
			when :cage_clusters
				create_class1_nanopub(annotation)
			when :gene_associations
				create_class2_nanopub(annotation, transcriptAssociation, geneEntrez, geneHgnc, geneUniprot)
			when :ff_expressions
				create_class3_nanopub(annotation, samples)
			end
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

			# main graph
			create_main_graph(nanopub, assertion, provenance, publicationInfo)

			# assertion graph
			location = FANTOM5["loc_#{annotation}"]
			orientation = sign == '+' ? RSO.forward : RSO.reverse
			insertGraph(assertion, [
				[FANTOM5[annotation], RDF.type, SO.SO_0001917],
				[FANTOM5[annotation], RSO.mapsTo, location],
				[location, RDF.type, RSO.SequenceLocation],
				[location, RSO.regionOf, HG19[chromosome]],
				[location, RSO.start, RDF::Literal.new(start_pos.to_i, :datatype => XSD.int)],
				[location, RSO.end, RDF::Literal.new(end_pos.to_i, :datatype =>XSD.int)],
				[location, RSO.hasOrientation, orientation]
			])

			# provenance graph
			create_provenance_graph(provenance, assertion)

			# publication info graph
			create_publication_info_graph(publicationInfo, nanopub)

			puts "inserted nanopub <#{nanopub}>"
		else
			puts "Unknown annotation format: #{annotation}"
		end
	end

	protected 
	def create_class2_nanopub(annotation, transcriptAssociation, geneEntrez, geneHgnc, geneUniprot)
		if transcriptAssociation =~ /(\d+)bp_to_(.*)_5end/
			base_offset, transcripts = $1, $2
			transcripts = transcripts.split(',')

			# setup nanopub
			nanopub = RDF::Vocabulary.new(@base['gene_associations/' + @row_index.to_s])
			assertion = nanopub['#assertion']
			provenance = nanopub['#provenance']
			publicationInfo = nanopub['#publicationInfo']

			# main graph
			create_main_graph(nanopub, assertion, provenance, publicationInfo)

			# assertion graph
			for transcript in transcripts
				if transcript =~ /^NM_/
					tss = FANTOM5["tss_#{transcript}"]
					entrez_id = geneEntrez.split(':')[1]
					insertGraph(assertion, [
						[FANTOM5[annotation], RSO.is_observation_of, tss],
						[tss, SO.part_of, RDF::URI.new("http://bio2rdf.org/geneid:#{entrez_id}")]
					])
				end
			end
			
			# provenance graph
			create_provenance_graph(provenance, assertion)

			# publication info graph
			create_publication_info_graph(publicationInfo, nanopub)

			#puts "#{transcriptAssociation}, #{geneEntrez}, #{geneHgnc}, #{geneUniprot}"
			puts "inserted nanopub <#{nanopub}>"
		else
			if transcriptAssociation != 'NA'
				puts "Unknown transcript association format: #{transcriptAssociation}"
			else
				puts "no transcript association on line #{@line_number}"
			end
		end
	end

	protected
	def create_class3_nanopub(annotation, samples)
		# TODO
	end


	private 
	def create_main_graph(nanopub, assertion, provenance, publicationInfo)
		insertGraph(nanopub, [
			[nanopub, RDF.type, NP.Nanopublicaiton],
			[nanopub, NP.hasAssertion, assertion],
			[nanopub, NP.hasProvenance, provenance],
			[nanopub, NP.hasPublicationInfo, publicationInfo]
		])
	end

	private 
	def create_provenance_graph(provenance, assertion)
		insertGraph(provenance, [
			[assertion, OBO.RO_0003001, RDF::URI.new('http://rdf.biosemantics.org/data/riken/fantom5/experiment')],
			[assertion, PROV.derivedFrom, RDF::URI.new("http://rdf.biosemantics.org/dataset/riken/fantom5/void/row_#{@row_index}")]
		])
	end

	private
	def create_publication_info_graph(publicationInfo, nanopub)
		insertGraph(publicationInfo, [
			[nanopub, PAV.authoredBy, RDF::URI.new('http://rdf.biosemantics.org/data/riken/fantom5/project')],
			[nanopub, PAV.createdBy, 'Andrew Gibson'],
			[nanopub, PAV.createdBy, 'Mark Thompson'],
			[nanopub, PAV.createdBy, 'Zuotian Tatum'],
			[nanopub, DC.rights, RDF::URI.new('http://creativecommons.org/licenses/by/3.0/')],
			[nanopub, DC.rightsHolder, RDF::URI.new('http://www.riken.jp/')],
			[nanopub, DC.created, RDF::Literal.new(Time.now.utc, :datatype => XSD.dateTime)]
		])
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
		options[:port] = port.to_i
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

	opts.on("--username USERNAME") do |username|
		options[:username] = username
	end

	opts.on("--password PASSWORD") do |password|
		options[:password] = password
	end

	opts.on("--type [TYPE]", [:cage_clusters, :gene_associations, :ff_expressions],
			"Select nanopublication subtype (cage_clusters, gene_associations, ff_expressions)") do |nanopub_type|
		options[:subtype] = nanopub_type
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

puts options

# do the work
converter = Fantom5_Nanopub_Converter.new(options)
converter.convert
