require 'rdf'
require 'rdf/turtle'
require 'slop'
require 'logger'

class RDF_Converter

	HEADER_PREFIX = '#'

	def initialize

		@options = get_options

		@base = RDF::Vocabulary.new(@options[:base_url])

		# tracking converter progress
		@line_number = 0  # incremented after a line is read from input
		@row_index = 0 # incremented before a line is converted.


    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
	end

	def convert
		File.open(@options[:input], 'r') do |f|

      time_start = Time.now.utc

			while line = f.gets
				@line_number += 1
				if line =~ /^#{HEADER_PREFIX}/
					convert_header_row(line.strip)
				else
					convert_row(line.strip)
        end

        if @row_index % 10 == 0
          @logger.info("============ running time: #{(Time.now.utc - time_start).to_s} ============")
        end
      end

      @logger.info("============ running time total: #{(Time.now.utc - time_start).to_s} ============")
		end
	end

	protected
	def convert_header_row(row)
		# do something
		puts "header: #{row}"
	end

	protected
	def convert_row(row)
		# do something
		@row_index += 1
		puts "row #{@row_index.to_s}: #{row}"
	end

	protected
	def save(ctx, triples)
		throw NotImplementedError.new
	end

	protected
	def get_options
		options = Slop.parse(:help=>true) do
		  on :i, :input=, 'input filename', :required => true
		  on :o, :output=, 'output filename'
		end
		options.to_hash
	end
end

class RDF_File_Converter < RDF_Converter

	def initialize
		super

		# useful stuff for serializing graph.
		@prefixes = {}
		@graph = RDF.Graph.new(@base)
	end

	def save(ctx, triples)
    triples.each do |s, p, o|
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


	def initialize
		super
		@server = AllegroGraph::Server.new(:host=>@options[:host], :port=>@options[:port], 
										   :username=>@options[:username], :password=>@options[:password])
		@catalog = @options[:catalog] ? AllegroGraph::Catalog.new(@server, @options[:catalog]) : @server 
		@repository = RDF::AllegroGraph::Repository.new(:server=>@catalog, :id=>@options[:repository])
		
		if @options[:clean]
			@repository.clear
		elsif @repository.size > 0 && !@options[:append]
			puts "repository is not empty (size = #{@repository.size}). Use --clean to clear repository before import, or use --append to ignore this setting."
			exit 1
		end
	end


	protected
	def save(ctx, triples)
		ctx_uri = ctx.to_uri
    triples.each do |s, p, o|
			@repository.insert([s.to_uri, p, o, ctx_uri])
		end
	end

	protected
	def get_options
		options = Slop.parse(:help => true) do
			on :host=, 'allegro graph host, default=localhost', :default => 'localhost'
			on :port=, 'default=10035', :as => :int, :default => 10035
			on :catalog=
			on :repository=, :required => true
			on :username=
			on :password=
			on :clean, 'clear the repository before import', :default => false
			on :append, 'allow adding new triples to a non-empty triple store.', :default => false
		end

		super.merge(options)
	end

	private
	def create_main_graph(nanopub, assertion, provenance, publication_info)
		save(nanopub, [
			[nanopub, RDF.type, NP.Nanopublicaiton],
			[nanopub, NP.hasAssertion, assertion],
			[nanopub, NP.hasProvenance, provenance],
			[nanopub, NP.hasPublicationInfo, publication_info]
		])
	end
end

