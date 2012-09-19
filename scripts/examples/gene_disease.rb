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
OPM = RDF::Vocabulary.new('http://purl.org/net/opmv/ns#')
base = RDF::Vocabulary.new('http://rdf.biosemantics.org/vocabularies/gene_disease_nanopub_example#')

prefixes = {
    :dcterms => DC,
    :np => NP,
    :rdf => RDF,
    :sio => SIO,
    :pav => PAV,
    :xsd => XSD,
    :rdfs => RDFS,
    nil => base
}


nanopub = base.to_uri
assertion = base.assertion
attribution = base.attribution
supporting = base.supporting

# create the default graph
graph = RDF::Graph.new(base)
graph << [nanopub, RDF.type, NP.Nanopublication]
graph << [nanopub, NP.hasAssertion, assertion]
graph << [nanopub, NP.hasAttribution, attribution]
graph << [nanopub, NP.hasSupporting, supporting]


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


# create the attribution graph
attribution_graph = RDF::Graph.new(attribution)

attribution_graph << [nanopub, DC.rights, URI('http://creativecommons.org/licenses/by/3.0/')]
attribution_graph << [nanopub, DC.rightsHolder, URI('http://biosemantics.org')]
attribution_graph << [nanopub, PAV.authoredBy, URI('http://www.researcherid.com/rid/B-6035-2012')]
attribution_graph << [nanopub, PAV.authoredBy, URI('http://www.researcherid.com/rid/B-5927-2012')]
attribution_graph << [nanopub, PAV.createdBy, URI('http://www.researcherid.com/rid/B-5852-2012')]
attribution_graph << [nanopub, DC.created, RDF::Literal.new(Time.now.utc, :datatype => XSD.dateTime)]

attribution_graph << [assertion, DC.created, RDF::Literal.new(Time.new(2012, 2, 9), :datatype => XSD.date)]
attribution_graph << [assertion, PAV.authoredBy, URI('http://www.researcherid.com/rid/B-6035-2012')]
attribution_graph << [assertion, PAV.authoredBy, URI('http://www.researcherid.com/rid/B-5927-2012')]


# create the supporting graph
supporting_graph = RDF::Graph.new(supporting)

supporting_graph << [assertion, OPM.wasDerivedFrom, RDF::URI.new('http://rdf.biosemantics.org/vocabularies/text_mining#gene_disease_concept_profiles_1980_2010')]
supporting_graph << [assertion, OPM.wasGeneratedBy, RDF::URI.new('http://rdf.biosemantics.org/vocabularies/text_mining#gene_disease_concept_profiles_matching_1980_2010')]


# let's take a look at the graphs
puts graph.dump(:trig, :prefixes => prefixes)
puts assertion_graph.dump(:trig, :prefixes => prefixes)
puts attribution_graph.dump(:trig, :prefixes => prefixes)
puts supporting_graph.dump(:trig, :prefixes => prefixes)

# store it in a file
RDF::TriG::Writer.open('test.trig') do |writer|
  writer.prefixes = prefixes
  writer.base_uri = base
  writer << graph
  writer << assertion_graph
  writer << attribution_graph
  writer << supporting_graph
end
