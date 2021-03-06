B   = require \backbone
_   = require \underscore
C   = require \../../collection
Sys = require \../../model/sys .instance
E   = require \./graph/edge
N   = require \./graph/node

const SIZE-NEW = 500px

module.exports = B.View.extend do
  get-nodes-xy: ->
    return null unless @map.get(\nodes)?length
    _.map @d3f.nodes!, ->
      _id: it._id
      x  : Math.round it.x
      y  : Math.round it.y
      pin: it.fixed

  get-size-x: -> @svg?attr \width
  get-size-y: -> @svg?attr \height

  initialize: ->
    var is-resized
    n-tick = 0
    @d3f = d3.layout.force!
      ..on \start ~>
        @trigger \pre-cool
        is-resized := false
      ..on \tick ~>
        return unless n-tick++ % 16 is 0
        @trigger \tick
        if @map.get-is-editable! and not is-resized and @d3f.alpha! < 0.03
          resize @
          @justify!
          is-resized := true # resize only once during cool-down
      ..on \end ~> # late render
        unless @is-rendered
          @map.parse-secondary-entities!
          @trigger \late-render
          @trigger \late-rendered
        @trigger \cooled
        unless @is-rendered
          @trigger \render-complete
          @is-rendered = true

  justify: ->
    return unless @svg # might be undefined e.g. new map
    # only apply flex if svg needs centering, due to bugs in flex when content exceeds container width
    if (@svg.attr \width) < @$el.width!
      @$el.css \display \flex
      @$el.css \align-items \center # vert
      @$el.css \justify-content \center # horiz
    else
      @$el.css \display \block
      @$el.css \justify-content \flex-start

  refresh-entities: (node-ids) -> # !!! client-side version of server-side logic in model/maps.ls
    @map.set \nodes _.map node-ids, (nid) ~>
      node = _.findWhere @d3f.nodes!, _id:nid
      _id: nid
      x  : node?x or @get-size-x!/2 # add new node to center
      y  : node?y or @get-size-y!/2
      pin: node?fixed
    @map.set \entities do
      nodes: new C.nodes C.Nodes.filter -> it.id in node-ids
      edges: new C.edges C.Edges.filter ~>
        return false unless it.is-in-map node-ids
        return true unless edge-cutoff-date = @map.get \edge_cutoff_date
        map-create-uid   = @map.get \meta .create_user_id
        edge-create-date = it.get \meta .create_date
        edge-create-uid  = it.get \meta .create_user_id
        edge-create-date < edge-cutoff-date or edge-create-uid is map-create-uid
      evidences: C.Evidences
    @

  render: (opts) ->
    return unless @$el?empty! # might be undefined for seo
    return @trigger \render-complete unless (entities = @map.get \entities)?nodes?length
    (ents = {}).nodes = entities.nodes.toJSON-T!
    ents.edges = entities.edges.toJSON-T nodes-json-by-id:_.indexBy ents.nodes, \_id
    @trigger \pre-render ents # ents can be modified by handlers
    for n in ents.nodes then n.class = n.classes * ' '
    for e in ents.edges then e.class = e.classes * ' '

    size-x = @map.get \size.x or @get-size-x! or SIZE-NEW
    size-y = @map.get \size.y or @get-size-y! or SIZE-NEW

    is-editable = @map.get-is-editable!
    unless @map.isNew!
      for n in @map.get \nodes when n.x?
        node = _.findWhere ents.nodes, _id:n._id
        node <<< { x:n.x, y:n.y, fixed:(not is-editable) or n.pin } if node?

    @d3f.nodes ents.nodes
     .links (ents.edges or [])
     .charge -2000
     .friction 0.85
     .linkDistance (edge) ->
       if \rename in edge.classes then 50 else 100
     .linkStrength (edge) ->
        const WEIGHTS =
          * class:\layer       weight:0
          * class:\rename      weight:20
          * class:\out-of-date weight:1
        w = _.find WEIGHTS, -> it.class in edge.classes
        x = if w then w.weight else 20
        x / (edge.source.weight + edge.target.weight)
     .size [size-x, size-y]
     .start!

    @is-rendered = false
    @svg = d3.select @el .append \svg:svg
    set-canvas-size @svg, size-x, size-y
    @justify!
    @trigger \render ents
    @svg.selectAll \g.node .call @d3f.drag if is-editable

    # determine whether to freeze immediately
    unless Sys.env is \test # no need to wait for cooldown when testing
      return if @map.isNew!
      return if opts?is-slow-to-cool

    @trigger \tick
    <~ _.defer   # yield thread for immediate map.show, before late render
    @d3f.alpha 0 # freeze map

## helpers

function set-canvas-size svg, w, h
  svg.attr \width w .attr \height h

function resize v
  const PADDING = 200px

  nodes = v.get-nodes-xy!
  xs = _.map nodes, -> it.x
  ys = _.map nodes, -> it.y
  w  = Math.max SIZE-NEW, (_.max xs) - (xmin = _.min xs) + 2 * PADDING
  h  = Math.max SIZE-NEW, (_.max ys) - (ymin = _.min ys) + 2 * PADDING

  size-before = x:v.get-size-x!, y:v.get-size-y!
  set-canvas-size v.svg, w, h
  v.d3f.size [w, h]
  v.map.set \size.x w
  v.map.set \size.y h

  # reposition fixed nodes
  dx = (w - size-before.x) / 2
  dy = (h - size-before.y) / 2
  for n in v.d3f.nodes! when n.fixed
    n.px += dx
    n.py += dy
