require 'rubygems'
require 'rdf'
require 'rdf/trig'

# namespaces
DC = RDF::DC
NP = RDF::Vocabulary.new('http://www.nanopub.org/nschema#')
SIO = RDF::Vocabulary.new('http://semanticscience.org/resource/')
base = RDF::Vocabulary.new('http://rdf.biosemantics.org/vocabularies/gene_disease_nanopub_example#')

prefixes = {
    :dcterms => DC,
    :np => NP,
    :rdf => RDF,
    :sio => SIO,
    :xsd => RDF::XSD,
    nil => base
}

# create the default graph
graph = RDF::Graph.new(base)
nanopub = base.to_uri
graph << [nanopub, RDF.type, NP.Nanopublication]
graph << [nanopub, DC.creator, "Zuotian Tatum"]
graph << [nanopub, NP.hasAssertion, base.assertion]


# create the assertion graph
assertion_graph = RDF::Graph.new(base.assertion)
association_1 = base['association1']
association_1_p_value = base['association1-p-value']

assertion_graph << [association_1, RDF.type, SIO['statistical-association']]
assertion_graph << [association_1, SIO['refers-to'], RDF::URI.new('http://bio2rdf.org/geneid:55835')]
assertion_graph << [association_1, SIO['refers-to'], RDF::URI.new('http://bio2rdf.org/omim:210600')]

assertion_graph << [association_1, SIO['has-measurement-value'], association_1_p_value]
assertion_graph << [association_1_p_value, RDF.type, SIO['probability-value']]
assertion_graph << [association_1_p_value, SIO['has-value'], RDF::Literal.new(0.0000656211037469712, :datatype => RDF::XSD.float)]


# let's take a look at the graphs
puts graph.dump(:trig, :prefixes => prefixes)
puts assertion_graph.dump(:trig, :prefixes => prefixes)

# store it in a file
RDF::TriG::Writer.open('test.trig') do |writer|
  writer.prefixes = prefixes
  writer.base_uri = base
  writer << graph
  writer << assertion_graph
end
