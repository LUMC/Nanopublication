require 'rdf'
require 'rdf/turtle'
require 'slop'

class RDF_Converter

	@@header_prefix = '#'

	def initialize()

		@options = get_options

		@base = RDF::Vocabulary.new(@options[:base_url])

		# tracking converter progress
		@line_number = 0  # incremented after a line is read from input
		@row_index = 0 # incremented before a line is converted.
	end

	def convert()
		File.open(@options[:input], 'r') do |f|
			while line = f.gets
				@line_number += 1
				if line =~ /^#{@@header_prefix}/
					convert_header_row(line.strip)
				else
					convert_row(line.strip)
				end
			end
		end
	end

	protected
	def convert_header_row(row)
		# do something
		puts 'header'
	end

	protected
	def convert_row(row)
		# do something
		@row_index += 1
		puts 'row'
	end

	protected
	def save(ctx, triples)
		throw NotImplementedError.new
	end

	protected
	def get_options()
		options = Slop.parse(:help=>true) do
		  on :i, :input=, "input filename", :required => true
		  on :o, :output=, 'output filename'
		end
		return options.to_hash
	end
end

class RDF_File_Converter < RDF_Converter

	def initialize(options)
		super

		# useful stuff for serializing graph.
		@prefixes = {}
		@graph = RDF.Graph.new(@base)
	end

	def save(ctx, triples)
		for s, p, o in triples do
			@graph << [s, p, o, ctx]
		end
	end
end

class RDF_Nanopub_Converter < RDF_Converter

	# Define some useful RDF vocabularies.
	FOAF = RDF::FOAF 
	DC = RDF::DC
	RDFS = RDF::RDFS
	XSD = RDF::XSD
	RSO = RDF::Vocabulary.new('http://rdf.biosemantics.org/ontologies/referencesequence#')
	HG19 = RDF::Vocabulary.new('http://rdf.biosemantics.org/data/genomeassemblies/hg19#')
	SO = RDF::Vocabulary.new('http://purl.org/obo/owl/SO#')
	PROV = RDF::Vocabulary.new('http://www.w3.org/ns/prov#')
	OBO = RDF::Vocabulary.new('http://purl.org/obo/owl/obo#')
	PAV = RDF::Vocabulary.new('http://swan.mindinformatics.org/ontologies/1.2/pav/')
	NP = RDF::Vocabulary.new('http://www.nanopub.org/nschema#')


	def initialize()
		super
		@server = AllegroGraph::Server.new(:host=>@options[:host], :port=>@options[:port], 
										   :username=>@options[:username], :password=>@options[:password])
		@catalog = @options[:catalog] ? @server : AllegroGraph::Catalog.new(@server, @options[:catalog])
		@repository = RDF::AllegroGraph::Repository.new(:server=>@catalog, :id=>@options[:repository])
		
		if @options[:clean]
			@repository.clear
		elsif @repository.count
			puts "repository is not empty. Use --clean to clear repository before import."
			exit 1
		end
	end


	protected
	def save(ctx, triples)
		ctx_uri = ctx.to_uri
		for s, p, o in triples do
			@repository.insert([s.to_uri, p, o, ctx_uri])
		end
	end

	protected
	def get_options()
		options = Slop.parse(:help => true) do
			on :host=, "allegro graph host, default=localhost", :default => 'localhost'
			on :port=, "default=10035", :as => :int, :default => 10035
			on :catalog=, :required => true
			on :repository=, :required => true
			on :username=, :default => 'agraph'
			on :password=, :default => 'agraph'
			on :clean, "clear the repository before import"
		end

		return super.merge(options)
	end

	private
	def create_main_graph(nanopub, assertion, provenance, publicationInfo)
		save(nanopub, [
			[nanopub, RDF.type, NP.Nanopublicaiton],
			[nanopub, NP.hasAssertion, assertion],
			[nanopub, NP.hasProvenance, provenance],
			[nanopub, NP.hasPublicationInfo, publicationInfo]
		])
	end
end

