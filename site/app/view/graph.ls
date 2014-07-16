B  = require \backbone
Fs = require \fs
_  = require \underscore
C  = require \../collection
E  = require \./graph/edge
Eg = require \./graph/edge-glyph
N  = require \./graph/node
O  = require \./graph/overlay
Ob = require \./graph/overlay/bil
Os = require \./graph/overlay/slit
S  = require \../session
V  = require \../view

T = Fs.readFileSync __dirname + \/graph.html

const OVERLAYS = [ Ob, O.Ac, O.Bis, O.Cfr ]
const SIZE = 1500

module.exports = B.View.extend do
  add-node: (id) ->
    nodes = (@map.get \nodes) or []
    ents  = (@map.get \entities) or { nodes:[] edges:[] evidences:[] }
    nodes.push _id:id, x:SIZE/2, y:SIZE/2
    nids = _.pluck nodes, \_id
    ents.nodes.push C.Nodes.get(id).attributes
    edges = C.Edges.filter -> (_.contains nids, it.get \a_node_id) and (_.contains nids, it.get \b_node_id)
    ents.edges = _.pluck edges, \attributes
    @map.set \nodes, nodes
    @map.set \entities, ents

  get-nodes: ->
    _.map @f.nodes!, ->
      id: it._id
      x : Math.round it.x
      y : Math.round it.y

  initialize: ->
    n-tick = 0
    @f = d3.layout.force!
      ..on \start, ~>
        @trigger \render
        _.each OVERLAYS, -> it.render-clear!
      ..on \tick, ->
        if n-tick++ > 4
          N .on-tick!
          E .on-tick!
          Eg.on-tick!
          n-tick := 0
      ..on \end, ~>
        _.each OVERLAYS, -> it.render!
        @svg
          .attr \width , SIZE
          .attr \height, SIZE
        @trigger \rendered

  remove-node: (id) ->
    nodes = @map.get \nodes
    ents  = @map.get \entities
    nodes = _.reject nodes, -> it._id is id
    ents.nodes = _.reject ents.nodes, -> it._id is id
    ents.edges = _.reject ents.edges, -> (it.a_node_id is id) or (it.b_node_id is id)
    @map.set \nodes, nodes
    @map.set \entities, ents

  render: (opts) ->
    log \render
    @$el.empty!
    return unless @el # might be undefined for seo
    return unless entities = @map.get \entities
    return unless (nodes = entities.nodes)?length

    edges = E.data entities
    edges = (Ob.filter-edges >> O.Ac.filter-edges >> O.Bis.filter-edges >> O.Cfr.filter-edges) edges
    nodes = Ob.filter-nodes nodes

    is-editable = @map.get-is-editable!
    fix-nodes!

    unless @map.isNew!
      for n in @map.get \nodes when n.x?
        node = _.findWhere nodes, _id:n._id
        node <<< { x:n.x, y:n.y } if node?

    @svg = d3.select @el .append \svg:svg
    @f.nodes nodes
     .charge -2000
     .friction 0.95
     .linkDistance 100
     .linkStrength E.get-strength
     .size [SIZE, SIZE]

    @f.links (edges or [])
    @f.start!

    is-slow-to-cool = @map.isNew! or opts?is-slow-to-cool
    @f.alpha 0.01 unless is-slow-to-cool # must invoke after start

    # order matters: svg uses painter's algo
    E .init @svg, @f
    N .init @svg, @f
    Os.init @svg, @f
    Eg.init @svg, @f
    _.each OVERLAYS, ~> it.init @svg, @f

    dragify-nodes!
    Os.align @svg, @f

    V.graph-toolbar.render!

    # helpers

    function fix-nodes then _.each nodes, -> it.fixed = (not is-editable) or N.is-you it

    ~function dragify-nodes then if is-editable then @svg.selectAll \g.node .call @f.drag

  show: ->
    return unless @el # might be undefined for seo
    @scroll = @scroll or x:0, y:0
    $window = $ window
    B.once \route-before, ~>
      @scroll.x = $window.scrollLeft!
      @scroll.y = $window.scrollTop!
    @$el.show!
    _.defer ~> $window .scrollTop(@scroll.y) .scrollLeft(@scroll.x)
