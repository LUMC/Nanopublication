require 'rdf'
require 'rdf/turtle'

module Nanopublication
	class RDF_Converter

		def initialize(options, header_prefix='#')
			@input = options[:input]
			@output = options[:output]
			@header_prefix = header_prefix

			# useful stuff for serializing graph.
			@prefixes = {}
			@base = RDF::Vocabulary.new(options[:base_url])

			# tracking converter progress
			@line_number = 0  # incremented after a line is read from input
			@row_index = 0 # incremented before a line is converted.
		end

		def convert()
			File.open(@input, 'r') do |f|
				while line = f.gets
					@line_number += 1
					if line[0] == @header_prefix
						convert_header_row(line.strip)
					else
						convert_row(line.strip)
					end
				end
			end
		end

		def convert_header_row(row)
			# do something
			puts 'header'
		end

		def convert_row(row)
			# do something
			@row_index += 1
			puts 'row'
		end

		def save_to_file()
			RDF::Turtle::Writer.open(@output) do |writer|
				writer.prefixes = @prefixes
				writer.base_uri = @base
				writer << graph
			end
		end

	end
end
