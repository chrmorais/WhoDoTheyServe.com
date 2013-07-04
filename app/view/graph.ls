B  = require \backbone
F  = require \fs
_  = require \underscore
V  = require \../view
E  = require \./graph/edge
EG = require \./graph/edge-glyph
FZ = require \./graph/freezer
N  = require \./graph/node
O  = require \./graph/overlay
OB = require \./graph/overlay/bil
OS = require \./graph/overlay/slit
P  = require \./graph/persister

T = F.readFileSync __dirname + \/graph.html

const HEIGHT = 2500
const WIDTH  = 2500

overlays = [ OB, O.Cfr, O.Bis ]

module.exports = B.View.extend do
  init: ->
    refresh @el, f = d3.layout.force!
    V.graph-toolbar
      ..render!
      ..on \save-layout, -> P.save-layout f
  render: ->
    @scroll = @scroll or x:500, y:700
    $window = $ window
    B.once \route-before, ~>
      @scroll.x = $window.scrollLeft!
      @scroll.y = $window.scrollTop!
    @$el.show!
    _.defer ~> $window .scrollTop(@scroll.y) .scrollLeft(@scroll.x)

function refresh el, f then
  $ el .empty!
  svg = d3.select el .append \svg:svg
    .attr \width , WIDTH
    .attr \height, HEIGHT

  nodes = N.data!
  edges = E.data nodes
  edges = (OB.filter-edges >> O.Cfr.filter-edges >> O.Bis.filter-edges) edges
  nodes = (OB.filter-nodes >> P.apply-layout >> FZ.fix-unless-admin) nodes

  f.nodes nodes
   .links edges
   .charge -2000
   .friction 0.95
   .linkDistance E.get-distance
   .linkStrength E.get-strength
   .size [WIDTH, HEIGHT]
   .start!
   .alpha 0.01 # settle immediately (must invoke after start)

  # order matters: svg uses painter's algo
  E .init svg, f
  N .init svg, f
  OS.init svg, f
  EG.init svg, f
  _.each overlays, -> it.init svg, f

  FZ.make-draggable-if-admin svg, f
  OS.align svg, f

  n-tick = 0
  f.on \end  , -> _.each overlays, -> it.render!
  f.on \start, -> _.each overlays, -> it.render-clear!
  f.on \tick, ->
    if n-tick++ % 4 is 0 then
      N .on-tick!
      E .on-tick!
      EG.on-tick!
