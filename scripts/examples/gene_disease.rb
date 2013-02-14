# Gene disease association nanopublication example.
# The main ontology for assertion is Semanticscience Integrated Ontology (SIO).

# Updated to nanopub schema 2.0


#require 'rubygems'
require 'rdf'
require 'rdf/trig'

# namespaces
DC = RDF::DC
RDFS = RDF::RDFS
XSD = RDF::XSD
NP = RDF::Vocabulary.new('http://www.nanopub.org/nschema#')
SIO = RDF::Vocabulary.new('http://semanticscience.org/resource/')
PAV = RDF::Vocabulary.new('http://swan.mindinformatics.org/ontologies/1.2/pav/')
PROV = RDF::Vocabulary.new('http://www.w3.org/ns/prov#')
base = RDF::Vocabulary.new('http://rdf.biosemantics.org/vocabularies/gene_disease_nanopub_example#')

prefixes = {
    :dcterms => DC,
    :np => NP,
    :rdf => RDF,
    :sio => SIO,
    :pav => PAV,
    :xsd => XSD,
    :rdfs => RDFS,
    :prov => PROV,
    nil => base
}


nanopub = base.to_uri
assertion = base.assertion
provenance = base.provenance
publicationInfo = base.publicationinfo

# create the default graph
graph = RDF::Graph.new(base)
graph << [nanopub, RDF.type, NP.Nanopublication]
graph << [nanopub, NP.hasAssertion, assertion]
graph << [nanopub, NP.hasProvenance, provenance]
graph << [nanopub, NP.hasPublicationInfo, publicationInfo]


# create the assertion graph
association_1 = base['association1']
association_1_p_value = base['association1-p-value']
assertion_graph = RDF::Graph.new(assertion)

assertion_graph << [association_1, RDF.type, SIO['statistical-association']]
assertion_graph << [association_1, SIO['refers-to'], URI('http://bio2rdf.org/geneid:55835')]
assertion_graph << [association_1, SIO['refers-to'], URI('http://bio2rdf.org/omim:210600')]
assertion_graph << [association_1, RDFS.comment, RDF::Literal.new('This association has p-value of 0.00066, has attribute gene CENPJ ' +
                                                                  '(Entrenz gene id 55835) and attribute disease Seckel Syndrome (OMIM 210600).', :language => 'en')]

assertion_graph << [association_1, SIO['has-measurement-value'], association_1_p_value]
assertion_graph << [association_1_p_value, RDF.type, SIO['probability-value']]
assertion_graph << [association_1_p_value, SIO['has-value'], RDF::Literal.new(0.0000656211037469712, :datatype => XSD.float)]


# create the provenance graph
provenance_graph = RDF::Graph.new(provenance)

provenance_graph << [assertion, PROV.wasDerivedFrom, RDF::URI.new('http://rdf.biosemantics.org/vocabularies/text_mining#gene_disease_concept_profiles_1980_2010')]
provenance_graph << [assertion, PROV.wasGeneratedBy, RDF::URI.new('http://rdf.biosemantics.org/vocabularies/text_mining#gene_disease_concept_profiles_matching_1980_2010')]


# create the publication info graph
publicationinfo_graph = RDF::Graph.new(publicationInfo)

publicationinfo_graph << [nanopub, DC.rights, URI('http://creativecommons.org/licenses/by/3.0/')]
publicationinfo_graph << [nanopub, DC.rightsHolder, URI('http://biosemantics.org')]
publicationinfo_graph << [nanopub, PAV.authoredBy, URI('http://www.researcherid.com/rid/B-6035-2012')]
publicationinfo_graph << [nanopub, PAV.authoredBy, URI('http://www.researcherid.com/rid/B-5927-2012')]
publicationinfo_graph << [nanopub, PAV.createdBy, URI('http://www.researcherid.com/rid/B-5852-2012')]
publicationinfo_graph << [nanopub, DC.created, RDF::Literal.new(Time.now.utc, :datatype => XSD.dateTime)]

# let's take a look at the graphs
puts graph.dump(:trig, :prefixes => prefixes)
puts assertion_graph.dump(:trig, :prefixes => prefixes)
puts provenance_graph.dump(:trig, :prefixes => prefixes)
puts publicationinfo_graph.dump(:trig, :prefixes => prefixes)

# store it in a file
RDF::TriG::Writer.open('test.trig') do |writer|
  writer.prefixes = prefixes
  writer.base_uri = base
  writer << graph
  writer << assertion_graph
  writer << provenance_graph
  writer << publicationinfo_graph
end
