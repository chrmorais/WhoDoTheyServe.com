Bh  = require \backbone .history
_   = require \underscore
C   = require \./collection
S   = require \./session
V   = require \./view
Ve  = require \./view-engine
Vee = require \./view/edge-edit
Vev = require \./view/evidence

const KEYCODE-ESC = 27

module.exports =
  init: (router) ->
    $ document .keyup -> if it.keyCode is KEYCODE-ESC then $ \.cancel .click!
    V
      ..edge-edit
        ..on \cancelled, -> Bh.history.back!
        ..on \destroyed, -> navigate \edges
        ..on \rendered ,    Vee.init
        ..on \saved    , -> nav-entity-saved \edge, &0, &1
      ..evidence-edit
        ..on \cancelled, -> nav-extra-done \evi
        ..on \destroyed, -> nav-extra-done \evi
        ..on \rendered ,    Vev.init
        ..on \saved    , -> nav-extra-done \evi
      ..map-edit
        ..on \destroyed ,    on-map-destroyed
        ..on \rendered  , ->
          V.map-nodes-sel.render C.Nodes, \name, _.pluck it.attributes.nodes, \_id
          # .on \click, -> log it
        ..on \saved     ,    on-map-saved
        ..on \serialized, ->
          it.attributes.nodes = for id in V.map-nodes-sel.get-selected-ids! then _id:id
      ..node-edit
        ..on \cancelled, -> Bh.history.back!
        ..on \destroyed, -> navigate \nodes
        ..on \rendered , -> $ \#name .typeahead source:C.Nodes.pluck \name
        ..on \saved    , -> nav-entity-saved \node, &0, &1
      ..note-edit
        ..on \cancelled, -> nav-extra-done \note
        ..on \destroyed, -> nav-extra-done \note
        ..on \saved    , -> nav-extra-done \note
      ..user-edit
        ..on \cancelled, -> Bh.history.back!
        ..on \destroyed, -> navigate \users
        ..on \saved    , -> navigate "user/#{it.id}"
      ..user-signin
        ..on \cancelled, -> Bh.history.back!
        ..on \saved    , -> navigate \session
      ..user-signout
        ..on \destroyed, -> navigate \session
      ..user-signup
        ..on \cancelled, -> Bh.history.back!
        ..on \saved    , -> navigate \session

    function navigate route then router.navigate route, trigger:true

    function nav-entity-saved name, entity, is-new
      return nav! unless is-new
      function nav path = '' then navigate "#name/#{entity.id}#path"
      <- Vev.create entity.id
      return nav if it?ok then '' else '/evi-new'

    function nav-extra-done name
      navigate Bh.fragment.replace new RegExp("/#name-.*$", \g), ''

    function on-map-destroyed
      V.navigator.render!
      navigate \session

    function on-map-saved map, is-new
      V.navigator.render!
      navigate "map/#{map.id}" if is-new

  reset: ->
    $ '.view' .off \focus, 'input[type=text]' .removeClass \ready
    $ '.view>*' .off!hide! # call off() so different views can use same element
    $ '.view>:not(.persist)' .empty! # leave persistent views e.g. graph
    V.navigator.render!
    Ve.ResetEditView!

  ready: ->
    $ \.timeago .timeago!
    # use a delgated event since view may still be rendering asyncly
    $ \.view .on \focus, 'input[type=text]', ->
      # defer, to workaround Chrome mouseup bug
      # http://stackoverflow.com/questions/2939122/problem-with-chrome-form-handling-input-onfocus-this-select
      _.defer ~> @select!
    <- _.defer
    $ \.btnNew:visible:first .focus!
    $ \.view .addClass \ready
