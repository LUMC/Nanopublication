require 'rdf'
require 'slop'
require_relative 'converter'

class Fantom5_Nanopub_Converter < RDF_Nanopub_Converter

  @@AnnotationSignChars = '+-'

  FANTOM5 = RDF::Vocabulary.new('http://rdf.biosemantics.org/data/riken/fantom5/data#')

  def convert_header_row(row)
    # do nothing
  end

  def convert_row(row)
    # ignore summary rows
    if row =~ /^chr/
      @row_index += 1
      annotation, shortDesc, description, transcriptAssociation, geneEntrez, geneHgnc, geneUniprot, *samples = row.split("\t")
      #puts "#{annotation}, #{shortDesc}, #{description}"
      case @options[:subtype]
        when 'cage_clusters'
          create_class1_nanopub(annotation)
        when 'gene_associations'
          create_class2_nanopub(annotation, transcriptAssociation, geneEntrez, geneHgnc, geneUniprot)
        when 'ff_expressions'
          create_class3_nanopub(annotation, samples)
      end
    end
  end

  protected
  def get_options
    options = Slop.parse(:help => true) do
      banner "ruby Fantom5_Nanopub_Converter.rb [options]\n"
      on :base_url=, :default => 'http://rdf.biosemantics.org/nanopubs/riken/fantom5/'
      on :subtype=, 'nanopub subtype, choose from [cage_clusters, gene_associations, ff_expressions]', :default => 'cage_clusters'
    end

    super.merge(options)
  end

  protected
  def create_class1_nanopub(annotation)
    if annotation =~ /(\w+):(\d+)\.\.(\d+),([#{@@AnnotationSignChars}])/
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
      save(assertion, [
          [FANTOM5[annotation], RDF.type, SO.SO_0001917],
          [FANTOM5[annotation], RSO.mapsTo, location],
          [location, RDF.type, RSO.SequenceLocation],
          [location, RSO.regionOf, HG19[chromosome]],
          [location, RSO.start, RDF::Literal.new(start_pos.to_i, :datatype => XSD.int)],
          [location, RSO.end, RDF::Literal.new(end_pos.to_i, :datatype => XSD.int)],
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
          save(assertion, [
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
  def create_provenance_graph(provenance, assertion)
    save(provenance, [
        [assertion, OBO.RO_0003001, RDF::URI.new('http://rdf.biosemantics.org/data/riken/fantom5/experiment')],
        [assertion, PROV.derivedFrom, RDF::URI.new("http://rdf.biosemantics.org/dataset/riken/fantom5/void/row_#{@row_index}")]
    ])
  end

  private
  def create_publication_info_graph(publicationInfo, nanopub)
    save(publicationInfo, [
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

# do the work
Fantom5_Nanopub_Converter.new.convert